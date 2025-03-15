#!/bin/bash

# Function to check if a file exists and matches expected size and checksum
check_file() {
    local file_path="$1"
    local expected_size="$2"
    local expected_checksum="$3"

    if [ -f "$file_path" ]; then
        local actual_size
        local actual_checksum

        actual_size=$(stat -c%s "$file_path")
        actual_checksum=$(sha256sum "$file_path" | awk '{print $1}')

        if [ "$actual_size" -eq "$expected_size" ] && [ "$actual_checksum" == "$expected_checksum" ]; then
            return 0  # File exists and matches
        else
            return 1  # File exists but does not match
        fi
    else
        return 2  # File does not exist
    fi
}

# Function to download a file
download_file() {
    local url="$1"
    local destination="$2"
    wget --no-clobber -P "$destination" "$url"
}

# Function to extract a tar file
extract_tar() {
    local tar_file="$1"
    local destination="$2"
    tar -xf "$tar_file" -C "$destination"
}

# Check if the packages directory is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 packages_dir build_dir"
    exit 1
fi

PACKAGES_DIR=$1
BUILD_DIR=$2

# Ensure the packages directory exists
if [ ! -d "$PACKAGES_DIR" ]; then
    echo "The specified packages directory does not exist: $PACKAGES_DIR"
    exit 1
fi

# Update package list
apt update

# Iterate over each subdirectory in the packages directory
for PACKAGE_DIR in "$PACKAGES_DIR"/*; do
    echo ${PACKAGE_DIR@A}
    if [ -d "$PACKAGE_DIR" ]; then
        PACKAGE_NAME=$(basename "$PACKAGE_DIR")

        SOURCE_INFO=$(apt-get -qq source --print-uris "$PACKAGE_NAME")

        # Check if the package was found
        if [ -z "$SOURCE_INFO" ]; then
            echo "No info found for package: $PACKAGE_NAME"
            continue
        fi

        # Get the .dsc file URL, size, and checksum
        DSC_INFO=$(grep -P '.*\.dsc ' <<< "$SOURCE_INFO")
        DSC_URL=$(echo "$DSC_INFO" | awk -F"'" '{print $2}')
        DSC_FILE=$(echo "$DSC_INFO" | awk '{print $2}')
        DSC_EXPECTED_SIZE=$(echo "$DSC_INFO" | awk '{print $3}')
        DSC_EXPECTED_CHECKSUM=$(echo "$DSC_INFO" | awk -F':' '{print $3}')

        # Ensure the existing directory exists
        mkdir -p "$PACKAGE_DIR"

        # Check if the .dsc file exists and matches
        if check_file "$PACKAGE_DIR/$DSC_FILE" "$DSC_EXPECTED_SIZE" "$DSC_EXPECTED_CHECKSUM"; then
            echo "File $DSC_FILE exists and matches in size and checksum. No action needed for $PACKAGE_NAME."
        else
            echo "File $DSC_FILE does not exist or does not match. Downloading..."
            download_file "$DSC_URL" "$PACKAGE_DIR"
            
            # Check the downloaded .dsc file
            if ! check_file "$PACKAGE_DIR/$DSC_FILE" "$DSC_EXPECTED_SIZE" "$DSC_EXPECTED_CHECKSUM"; then
                echo "Downloaded file $DSC_FILE does not match expected size or checksum for $PACKAGE_NAME."
                continue
            fi

            # Get the .debian.tar.* file URL, size, and checksum
            DEBIAN_TAR_INFO=$(grep -P '.*\.debian.tar.(xz|gz) ' <<< "$SOURCE_INFO")
            DEBIAN_TAR_URL=$(echo "$DEBIAN_TAR_INFO" | awk -F"'" '{print $2}')
            DEBIAN_TAR_FILE=$(echo "$DEBIAN_TAR_INFO" | awk '{print $2}')
            DEBIAN_TAR_EXPECTED_SIZE=$(echo "$DEBIAN_TAR_INFO" | awk '{print $3}')
            DEBIAN_TAR_EXPECTED_CHECKSUM=$(echo "$DEBIAN_TAR_INFO" | awk -F':' '{print $3}')

            # Ensure the build directory exists (define BUILD_DIR as needed)
            mkdir -p "$BUILD_DIR"

            # Download the .debian.tar.* file
            echo "Downloading $DEBIAN_TAR_FILE for $PACKAGE_NAME..."
            download_file "$DEBIAN_TAR_URL" "$PACKAGE_DIR"

            # Check the downloaded .debian.tar.* file
            if ! check_file "$PACKAGE_DIR/$DEBIAN_TAR_FILE" "$DEBIAN_TAR_EXPECTED_SIZE" "$DEBIAN_TAR_EXPECTED_CHECKSUM"; then
                echo "Downloaded file $DEBIAN_TAR_FILE does not match expected size or checksum for $PACKAGE_NAME."
                continue
            fi

            # Extract the .debian.tar.* file into the build directory
            extract_tar "$PACKAGE_DIR/$DEBIAN_TAR_FILE" "$BUILD_DIR"
            echo "Extracted $DEBIAN_TAR_FILE to $BUILD_DIR for $PACKAGE_NAME."
        fi
    fi
done
