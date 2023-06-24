#!/bin/bash

# Get the directory path of the script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Change to the script's directory
cd "$script_dir"

# Function to check if a package is installed
check_package() {
  if [ -x "$(command -v dpkg-query)" ]; then
    # Ubuntu
    if dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"; then
      return 0
    fi
  elif [ -x "$(command -v rpm)" ] && [ -x "$(command -v dnf)" ]; then
    # Fedora
    if rpm -q "$1" >/dev/null 2>&1 || dnf list installed "$1" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

# Function to check if a directory exists
check_directory() {
  if [ ! -d "$1" ]; then
    return 1
  fi
  return 0
}

# Function to check if a file exists
check_file() {
  if [ ! -f "$1" ]; then
    return 1
  fi
  return 0
}

# Check if packages are not installed
if ! check_package openssl || ! check_package unzip || ! check_package mokutil || ! check_package efitools || ! check_package curl; then
  # Check if directories don't exist
  download_dir="$script_dir/Download"
  efikeys_dir="$script_dir/efikeys"
  if ! check_directory "$download_dir/X64" || ! check_directory "$download_dir/Docs" || ! check_directory "$download_dir/Utilities" || ! check_directory "$efikeys_dir"; then
      # Check internet connectivity
      if dig +short google.com > /dev/null 2>&1; then
        echo "Internet is available."
      else
        # New nameserver IP addresses
        primary_dns="8.8.8.8"
        secondary_dns="8.8.4.4"
        # Backup the original resolv.conf file
        sudo cp /etc/resolv.conf /etc/resolv.conf.backup
        # Update the nameserver IP addresses
        sudo sed -i "s/^nameserver .*/nameserver $primary_dns\nnameserver $secondary_dns/" /etc/resolv.conf
        echo "Nameserver configuration updated."
        echo "Internet is available."
      fi
    fi
  fi
else
  echo "All required packages, directories, and files are already available."
fi

function check_installation {
    package_name=$1
    if ! dpkg -s $package_name &> /dev/null && ! rpm -q $package_name &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            echo "$package_name is not installed. Installing with APT..."
            sudo apt-get update
            sudo apt-get install -y $package_name
        elif command -v dnf &> /dev/null; then
            echo "$package_name is not installed. Installing with DNF..."
            sudo dnf install -y $package_name
        else
            echo "Neither APT nor DNF package managers found. Unable to install $package_name."
            exit 1
        fi
    fi
}

check_installation "openssl"
check_installation "unzip"
check_installation "mokutil"
check_installation "efitools"
check_installation "curl"

efikeys_dir="$script_dir/efikeys"
if [ ! -d "$efikeys_dir" ]; then
  mkdir "$efikeys_dir"
fi

download_dir="$script_dir/Download"
if [ ! -d "$download_dir" ]; then
  mkdir "$download_dir"
fi

system_dir="$script_dir/system-files"
if [ ! -d "$system_dir" ]; then
  mkdir "$system_dir"
fi

# Function to create certificate and key
function create_cert_key {
    # Create PK (Platform Key)
    if [ ! -f "$efikeys_dir/PK.key" ] || [ ! -f "$efikeys_dir/PK.pem" ]; then
    rm "$efikeys_dir/PK.key" 2>/dev/null && rm "$efikeys_dir/PK.pem" 2>/dev/null
    openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes -subj "/CN=OpenCore PK Platform Key/" -keyout "$efikeys_dir/PK.key" -out "$efikeys_dir/PK.pem" -outform PEM
    fi

    # Create KEK (Key Exchange Key)
    if [ ! -f "$efikeys_dir/KEK.key" ] || [ ! -f "$efikeys_dir/KEK.pem" ]; then
    rm "$efikeys_dir/KEK.key" 2>/dev/null && rm "$efikeys_dir/KEK.pem" 2>/dev/null
    openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes -subj "/CN=OpenCore KEK Exchange Key/" -keyout "$efikeys_dir/KEK.key" -out "$efikeys_dir/KEK.pem" -outform PEM
    fi

    # Create ISK (Initial Supplier Key)
    if [ ! -f "$efikeys_dir/ISK.key" ] || [ ! -f "$efikeys_dir/ISK.pem" ]; then
    rm "$efikeys_dir/ISK.key" 2>/dev/null && rm "$efikeys_dir/ISK.pem" 2>/dev/null
    openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes -subj "/CN=OpenCore ISK Image Signing Key/" -keyout "$efikeys_dir/ISK.key" -out "$efikeys_dir/ISK.pem" -outform PEM
    fi

    # Permission for key files
    chmod 0600 "$efikeys_dir"/*.key

    # Convert PEM files to ESL format suitable for UEFI Secure Boot
    if [ ! -f "$efikeys_dir/PK.esl" ]; then
    cert-to-efi-sig-list -g $(uuidgen) "$efikeys_dir/PK.pem" "$efikeys_dir/PK.esl"
    fi
    if [ ! -f "$efikeys_dir/KEK.esl" ]; then
    cert-to-efi-sig-list -g $(uuidgen) "$efikeys_dir/KEK.pem" "$efikeys_dir/KEK.esl"
    fi
    if [ ! -f "$efikeys_dir/ISK.esl" ]; then
    cert-to-efi-sig-list -g $(uuidgen) "$efikeys_dir/ISK.pem" "$efikeys_dir/ISK.esl"
    fi

    # Create the database
    if [ ! -f "$efikeys_dir/db.esl" ]; then
    cat "$efikeys_dir/ISK.esl" > "$efikeys_dir/db.esl"
    fi

    # Digitally sign ESL files
    # PK sign
    if [ ! -f "$efikeys_dir/PK.auth" ]; then
    openssl x509 -in "$efikeys_dir/PK.pem" -outform der -out "$efikeys_dir/PK.auth"
    cat "$efikeys_dir/PK.key" >> "$efikeys_dir/PK.auth"
    cat "$efikeys_dir/PK.esl" >> "$efikeys_dir/PK.auth"
    fi
    # KEK is signed with PK
    if [ ! -f "$efikeys_dir/KEK.auth" ]; then
    openssl x509 -in "$efikeys_dir/PK.pem" -outform der -out "$efikeys_dir/KEK.auth"
    cat "$efikeys_dir/PK.key" >> "$efikeys_dir/KEK.auth"
    cat "$efikeys_dir/KEK.esl" >> "$efikeys_dir/KEK.auth"
    fi
    # the database is signed with KEK
    if [ ! -f "$efikeys_dir/db.auth" ]; then
    openssl x509 -in "$efikeys_dir/KEK.pem" -outform der -out "$efikeys_dir/db.auth"
    cat "$efikeys_dir/KEK.key" >> "$efikeys_dir/db.auth"
    cat "$efikeys_dir/db.esl" >> "$efikeys_dir/db.auth"
    fi

    ISK_key="$efikeys_dir/ISK.key"
    ISK_pem="$efikeys_dir/ISK.pem"
}

# Call the function to create certificate and key
create_cert_key

if [ -d "$download_dir/X64" ] && [ -d "$download_dir/Docs" ] && [ -d "$download_dir/Utilities" ]; then
  echo "All three directories (X64, Docs, Utilities) exist."
  # Add your desired code here when all directories exist
else
  echo "One or more directories are missing."
  # Define the GitHub repository
  repository="acidanthera/OpenCorePkg"
  # Get the latest release information from the GitHub API
  release_info=$(curl -s "https://api.github.com/repos/$repository/releases/latest")
  # Filter out debug assets
  download_url=$(echo "$release_info" | jq -r '.assets | map(select(.name | test("DEBUG"; "i") | not)) | .[0].browser_download_url')
  # Extract the file name from the download URL
  file_name=$(basename "$download_url")
  # Define the destination file path
  destination_path="$download_dir/$file_name"
  # Download the latest OpenCore zip file
  curl -L -o "$destination_path" "$download_url"
  # Check if X64 directory is missing
  if [ ! -d "$download_dir/X64" ]; then
  # unzip X64 directory from OpenCore
  unzip -q "$destination_path" "X64/*" -d "$download_dir"
  fi
  # Check if Docs directory is missing
  if [ ! -d "$download_dir/Docs" ]; then
  # unzip Docs directory from OpenCore
  unzip -q "$destination_path" "Docs/*" -d "$download_dir"
  fi
  # Check if Utilities directory is missing
  if [ ! -d "$download_dir/Utilities" ]; then
  # unzip Utilities directory from OpenCore
  unzip -q "$destination_path" "Utilities/*" -d "$download_dir"
  fi
  # Clean up
  rm "$destination_path" 2>/dev/null
fi

# Source folder
src_folder="$system_dir"
# Destination folder
dest_folder="$download_dir/X64/EFI/OC"
# Copy files with overwrite
cp -r -f "$src_folder"/* "$dest_folder"

# Create the X64-Signed directory
if [ -d "$download_dir/X64-Signed" ]; then
  rm -rf "$download_dir/X64-Signed"
fi
mkdir -p "$download_dir/X64-Signed"
X64_Signed="$download_dir/X64-Signed"

# Source folder
src_folder="$download_dir/X64"
# Destination folder
dest_folder="$download_dir/X64-Signed"
# Copy files with overwrite
cp -r -f "$src_folder"/* "$dest_folder"

# Sign .efi .kext files in X64-Signed directory and subdirectories
find "$X64_Signed" -type f \( -name "*.efi" -o -name "*.kext" \) -print0 | while IFS= read -r -d '' file; do
    # Sign the file using sbsign and override the original file
    sbsign --key "$ISK_key" --cert "$ISK_pem" --output "$file" "$file"
done

# Function to install OpenCore without secure boot
install_without_secure_boot() {
  # Find the EFI partition
  efi_partition=$(findmnt -n -o SOURCE -T /boot/efi)
  # Mount the EFI partition
  sudo mount "$efi_partition" /mnt
  # Copy files from X64-Signed folder to the EFI partition
  sudo cp -R "$download_dir/X64"* /mnt
  # Set the description for the boot option
  BOOT_OPTION_DESC="Opencore Bootloader"
  # Set the path to the Opencore bootloader in the EFI partition
  EFI_PATH="/efi/EFI/OC/OpenCore.efi"
  # Check if the boot option already exists
  existing_boot_option=$(sudo efibootmgr | grep "$BOOT_OPTION_DESC")
  if [[ -z "$existing_boot_option" ]]; then
      # Add the boot option using efibootmgr
      sudo efibootmgr --create --label "$BOOT_OPTION_DESC" --disk "$efi_partition" --loader "$EFI_PATH" --verbose --bootnum 0000
  else
      echo "Opencore boot option already exists."
  fi
  # Unmount the EFI partition
  sudo umount /mnt
}

# Function to install OpenCore with secure boot
install_with_secure_boot() {
  # add .auth files into uefi firmware
  # Check if the PK.auth file is already imported
sudo mokutil --test-key "$efikeys_dir/PK.auth"
pk_imported=$?
# Check if the KEK.auth file is already imported
sudo mokutil --test-key "$efikeys_dir/KEK.auth"
kek_imported=$?
# Check if the db.auth file is already imported
sudo mokutil --test-key "$efikeys_dir/db.auth"
db_imported=$?
# Import the PK.auth file if not already imported
if [[ $pk_imported -ne 0 ]]; then
  sudo mokutil --import "$efikeys_dir/PK.auth"
fi
# Import the KEK.auth file if not already imported
if [[ $kek_imported -ne 0 ]]; then
  sudo mokutil --import "$efikeys_dir/KEK.auth"
fi
# Import the db.auth file if not already imported
if [[ $db_imported -ne 0 ]]; then
  sudo mokutil --import "$efikeys_dir/db.auth"
fi
  # Find the EFI partition
  efi_partition=$(findmnt -n -o SOURCE -T /boot/efi)
  # Mount the EFI partition
  sudo mount "$efi_partition" /mnt
  # Copy files from X64-Signed folder to the EFI partition
  sudo cp -R "$download_dir/X64-Signed"* /mnt
  # Set the description for the boot option
  BOOT_OPTION_DESC="Opencore Bootloader"
  # Set the path to the Opencore bootloader in the EFI partition
  EFI_PATH="/efi/EFI/OC/OpenCore.efi"
  # Check if the boot option already exists
  existing_boot_option=$(sudo efibootmgr | grep "$BOOT_OPTION_DESC")
  if [[ -z "$existing_boot_option" ]]; then
      # Add the boot option using efibootmgr
      sudo efibootmgr --create --label "$BOOT_OPTION_DESC" --disk "$efi_partition" --loader "$EFI_PATH" --verbose --bootnum 0000
  else
      echo "Opencore boot option already exists."
  fi
  # Unmount the EFI partition
  sudo umount /mnt
}

# Prompt user for installation type
echo "OpenCore Installation"
echo "---------------------"
echo "Please select the installation type:"
echo "1. Install with secure boot"
echo "2. Install without secure boot"
echo "3. Do not install OpenCore"
echo "BEFORE INSTALL MUST MODIFY system-files FOLDER FOR YOUR SYSTEM"
echo "anything inside system-files will be added to Download/X64/EFI/OC/"
read -p "Enter your choice (1, 2, or 3): " choice

# Validate the user's choice and execute the appropriate function
if [[ $choice == 1 ]]; then
  install_with_secure_boot
elif [[ $choice == 2 ]]; then
  install_without_secure_boot
elif [[ $choice == 3 ]]; then
  echo "Skipping OpenCore installation."
else
  echo "Invalid choice. Please select 1, 2, or 3."
fi
