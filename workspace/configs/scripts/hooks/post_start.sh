#!/usr/bin/env bash

# Check available disk space
check_disk_space() {
    local required_mb="${1:-1024}"  # Default 1GB
    local available_mb
    available_mb=$(df /workspace --output=avail -BM 2>/dev/null | tail -1 | tr -d 'M ')
    
    if [[ -z "${available_mb}" ]]; then
        echo -e "DOWNLOAD: WARNING: Could not determine available disk space"
        return 0  # Continue anyway if we can't check
    fi
    
    if [[ ${available_mb} -lt ${required_mb} ]]; then
        echo -e "DOWNLOAD: WARNING: Low disk space! Available: ${available_mb}MB, Required: ${required_mb}MB"
        return 1
    fi
    return 0
}

download_file() {
    local url="$1"
    local destination_dir="$2"
    
    # Extract filename from URL
    local filename
    filename=$(basename "${url%%\?*}")
    local destination_path="${destination_dir}/${filename}"
    
    # Check if file already exists
    if [[ -f "${destination_path}" ]]; then
        echo -e "DOWNLOAD: SKIP: File already exists: ${destination_path}"
        return 0
    fi
    
    # Check disk space before downloading (warn if less than 5GB available)
    if ! check_disk_space 5120; then
        echo -e "DOWNLOAD: ERROR: Insufficient disk space to download ${filename}"
        return 1
    fi
    
    # Create destination directory
    mkdir -p "${destination_dir}"
    
    # Build wget command with authentication if needed
    local wget_cmd="wget --progress=bar:force"
    local download_url="${url}"
    
    # Add HuggingFace authentication header if URL matches and token is set
    if [[ "${url}" == *"huggingface.co"* ]] && [[ -n "${HF_TOKEN}" ]]; then
        wget_cmd="${wget_cmd} --header=\"Authorization: Bearer ${HF_TOKEN}\""
        echo "DOWNLOAD: Using HuggingFace authentication..."
    fi
    
    # Add Civitai API key if URL matches and key is set
    if [[ "${url}" == *"civitai.com"* ]] && [[ -n "${CIVITAI_API_KEY}" ]]; then
        if [[ "${url}" == *"?"* ]]; then
            download_url="${url}&token=${CIVITAI_API_KEY}"
        else
            download_url="${url}?token=${CIVITAI_API_KEY}"
        fi
        echo "DOWNLOAD: Using Civitai authentication..."
    fi
    
    # Download file with wget, capturing both stdout and stderr
    echo "DOWNLOAD: Downloading ${filename} to ${destination_dir}..."
    local wget_output
    local wget_exit_code
    
    # Run wget and capture output
    wget_output=$(eval "${wget_cmd} -O \"${destination_path}\" \"${download_url}\"" 2>&1)
    wget_exit_code=$?
    
    if [[ ${wget_exit_code} -eq 0 ]]; then
        echo -e "DOWNLOAD: SUCCESS: ${filename} downloaded to ${destination_path}\n"
        return 0
    else
        echo -e "\nDOWNLOAD: ERROR: Failed to download ${filename}"
        echo -e "DOWNLOAD: ERROR: URL: ${url}"
        
        # Check for specific error conditions
        if echo "${wget_output}" | grep -qi "cannot write\|no space\|disk full"; then
            echo -e "DOWNLOAD: ERROR: DISK FULL - No space left on device!"
        elif echo "${wget_output}" | grep -qi "404\|not found"; then
            echo -e "DOWNLOAD: ERROR: File not found (404)"
        elif echo "${wget_output}" | grep -qi "403\|forbidden"; then
            echo -e "DOWNLOAD: ERROR: Access forbidden (403) - check authentication"
        elif echo "${wget_output}" | grep -qi "401\|unauthorized"; then
            echo -e "DOWNLOAD: ERROR: Unauthorized (401) - check credentials"
        else
            # Show the last few lines of wget output for other errors
            echo -e "DOWNLOAD: ERROR: Reason: $(echo "${wget_output}" | tail -3)"
        fi
        
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
    
    # Check initial disk space
    check_disk_space 1024  # Warn if less than 1GB
    
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
    
    # Temporary file for tracking failed downloads
    local failed_downloads
    failed_downloads=$(mktemp)
    
    # Extract all downloads for specified groups and deduplicate
    for group in "${groups_array[@]}"; do
        group=$(echo "${group}" | xargs)  # Trim whitespace
        echo "DOWNLOAD: Processing group: ${group}"
        
        # Extract downloads for this group using pipe delimiter
        yq -r ".groups[] | select(.name == \"${group}\") | .downloads[] | .url + \"|\" + .destination" "${downloads_config}" 2>/dev/null | while IFS='|' read -r url destination; do
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
        rm -f "${temp_downloads}" "${failed_downloads}"
        return
    fi
    
    echo -e "\n\nDOWNLOAD: Found ${total_downloads} unique files to download."
    
    # Determine download mode (async or sync)
    local download_mode="${DOWNLOAD_MODE:-async}"
    echo -e "DOWNLOAD: Mode: ${download_mode}\n\n"
    
    # Track background jobs for async mode
    local -a download_pids=()
    local -a download_urls=()
    
    # Process each download
    local count=0
    while IFS='|' read -r url destination; do
        ((count++))
        echo -e "\n\nDOWNLOAD: [${count}/${total_downloads}] Processing: ${url}\n\n"
        
        if [[ "${download_mode}" == "async" ]]; then
            # Download in background
            download_file "${url}" "${destination}" &
            download_pids+=($!)
            download_urls+=("${url}")
        else
            # Download synchronously
            if ! download_file "${url}" "${destination}"; then
                echo "${url}" >> "${failed_downloads}"
            fi
        fi
    done < "${temp_downloads}"
    
    # Wait for all background downloads to complete in async mode
    if [[ "${download_mode}" == "async" && ${#download_pids[@]} -gt 0 ]]; then
        echo "DOWNLOAD: Waiting for ${#download_pids[@]} background downloads to complete..."
        local i=0
        for pid in "${download_pids[@]}"; do
            if ! wait "${pid}"; then
                echo "${download_urls[$i]}" >> "${failed_downloads}"
            fi
            ((i++))
        done
        echo -e "\n\nDOWNLOAD: All background downloads completed."
    fi
    
    # Report summary
    local failed_count
    failed_count=$(wc -l < "${failed_downloads}" 2>/dev/null || echo "0")
    local success_count=$((total_downloads - failed_count))
    
    echo -e "\n"
    echo "================================================================================"
    echo "DOWNLOAD SUMMARY"
    echo "================================================================================"
    echo "  Total files:     ${total_downloads}"
    echo "  Successful:      ${success_count}"
    echo "  Failed:          ${failed_count}"
    
    if [[ ${failed_count} -gt 0 ]]; then
        echo ""
        echo "FAILED DOWNLOADS:"
        while IFS= read -r url; do
            echo "  - ${url}"
        done < "${failed_downloads}"
        echo ""
        echo "DOWNLOAD: WARNING: ${failed_count} download(s) failed! Check logs above for details."
    fi
    echo "================================================================================"
    
    # Cleanup
    rm -f "${temp_downloads}" "${failed_downloads}"
    
    echo -e "DOWNLOAD: Download process complete.\n\n"
}

echo "POST-START: START --------------------------------------------------------------"

echo -e "\n\n\nPOST-START: DOWNLOADING MODELS -------------------------------------------------"
parse_and_download_models

echo -e "\n\n\nPOST-START: DONE ---------------------------------------------------------------"
echo -e "--------------------------------------------------------------------------------\n\n"
