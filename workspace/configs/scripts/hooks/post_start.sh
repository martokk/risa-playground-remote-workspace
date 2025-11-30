#!/usr/bin/env bash

download_file() {
    local url="$1"
    local destination_dir="$2"
    
    # Extract filename from URL
    local filename
    filename=$(basename "${url%%\?*}")
    local destination_path="${destination_dir}/${filename}"
    
    # Check if file already exists
    if [[ -f "${destination_path}" ]]; then
        echo "DOWNLOAD: SKIP: File already exists: ${destination_path}"
        return 0
    fi
    
    # Create destination directory
    mkdir -p "${destination_dir}"
    
    # Download file with wget
    echo "DOWNLOAD: Downloading ${filename} to ${destination_dir}..."
    if wget --progress=bar:force -O "${destination_path}" "${url}" 2>&1; then
        echo "DOWNLOAD: SUCCESS: ${filename}"
        return 0
    else
        echo "DOWNLOAD: ERROR: Failed to download ${url}"
        rm -f "${destination_path}"  # Clean up partial download
        return 1
    fi
}

parse_and_download_models() {
    local downloads_config="/workspace/configs/downloads.yaml"
    
    # Check if downloads.yaml exists
    if [[ ! -f "${downloads_config}" ]]; then
        echo "DOWNLOAD: Config file not found at ${downloads_config}. Skipping downloads."
        return
    fi
    
    echo "DOWNLOAD: Starting model downloads..."
    
    # Get download groups from environment variable or YAML
    local download_groups
    if [[ -n "${DOWNLOAD_GROUPS}" ]]; then
        echo "DOWNLOAD: Using groups from DOWNLOAD_GROUPS env var: ${DOWNLOAD_GROUPS}"
        download_groups="${DOWNLOAD_GROUPS}"
    else
        # Extract download_groups from YAML
        download_groups=$(yq -r '.download_groups | join(",")' "${downloads_config}")
        echo "DOWNLOAD: Using groups from YAML: ${download_groups}"
    fi
    
    # Convert comma-separated groups to array
    IFS=',' read -ra groups_array <<< "${download_groups}"
    
    # Temporary file for storing unique downloads
    local temp_downloads
    temp_downloads=$(mktemp)
    
    # Extract all downloads for specified groups and deduplicate
    for group in "${groups_array[@]}"; do
        group=$(echo "${group}" | xargs)  # Trim whitespace
        echo "DOWNLOAD: Processing group: ${group}"
        
        # Extract downloads for this group
        yq -r ".groups[] | select(.name == \"${group}\") | .downloads[] | .url + \"\u0000\" + .destination" "${downloads_config}" 2>/dev/null | while IFS= read -r -d '' url && IFS= read -r -d '' destination; do
            # Skip empty entries
            if [[ -z "${url}" || -z "${destination}" ]]; then
                continue
            fi
            
            # Add to temp file (will be deduplicated later)
            echo "${url}|${destination}" >> "${temp_downloads}"
        done
    done
    
    # Deduplicate entries
    sort -u "${temp_downloads}" -o "${temp_downloads}"
    
    # Count total downloads
    local total_downloads
    total_downloads=$(wc -l < "${temp_downloads}")
    
    if [[ ${total_downloads} -eq 0 ]]; then
        echo "DOWNLOAD: No downloads to process."
        rm -f "${temp_downloads}"
        return
    fi
    
    echo "DOWNLOAD: Found ${total_downloads} unique files to download."
    
    # Determine download mode (async or sync)
    local download_mode="${DOWNLOAD_MODE:-async}"
    echo "DOWNLOAD: Mode: ${download_mode}"
    
    # Track background jobs for async mode
    local -a download_pids=()
    
    # Process each download
    local count=0
    while IFS='|' read -r url destination; do
        ((count++))
        echo "DOWNLOAD: [${count}/${total_downloads}] Processing: ${url}"
        
        if [[ "${download_mode}" == "async" ]]; then
            # Download in background
            download_file "${url}" "${destination}" &
            download_pids+=($!)
        else
            # Download synchronously
            download_file "${url}" "${destination}"
        fi
    done < "${temp_downloads}"
    
    # Wait for all background downloads to complete in async mode
    if [[ "${download_mode}" == "async" && ${#download_pids[@]} -gt 0 ]]; then
        echo "DOWNLOAD: Waiting for ${#download_pids[@]} background downloads to complete..."
        for pid in "${download_pids[@]}"; do
            wait "${pid}" 2>/dev/null || true
        done
        echo "DOWNLOAD: All background downloads completed."
    fi
    
    # Cleanup
    rm -f "${temp_downloads}"
    
    echo "DOWNLOAD: Download process complete."
}

echo "POST-START: START --------------------------------------------------------------"

echo "POST-START: DOWNLOADING MODELS -------------------------------------------------"
parse_and_download_models

echo "POST-START: DONE ---------------------------------------------------------------"
echo "--------------------------------------------------------------------------------\n\n"
