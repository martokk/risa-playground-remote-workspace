#!/usr/bin/env bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <OLD_VENV> <NEW_VENV>"
    echo "   eg: $0 /venv /workspace/venv"
    exit 1
fi

OLD_PATH=${1}
NEW_PATH=${2}

echo "VENV: Fixing venv. Old Path: ${OLD_PATH}  New Path: ${NEW_PATH}"

cd ${NEW_PATH}/bin

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")

echo "Python version is ${PYTHON_VERSION}.x"

# Update the venv path in the activate script - handle both quoted and unquoted formats
# First, try to replace quoted format
sed -i "s|VIRTUAL_ENV=\"${OLD_PATH}\"|VIRTUAL_ENV=\"${NEW_PATH}\"|" activate
# Then, try to replace unquoted format (in case the first didn't match)
sed -i "s|VIRTUAL_ENV=${OLD_PATH}|VIRTUAL_ENV=${NEW_PATH}|" activate

# Update the venv path in the shebang for all files containing a shebang
sed -i "s|#\!${OLD_PATH}/bin/python3|#\!${NEW_PATH}/bin/python3|" *
