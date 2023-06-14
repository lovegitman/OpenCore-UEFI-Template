#!/bin/bash

read -p "Are you connected to the internet? (y/n): " answer
answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]') # Convert answer to lowercase
if [ "$answer" = "y" ]; then
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
elif [ "$answer" = "n" ]; then
  echo "connect to internet and try again."
  exit 1
else
  echo "Invalid input. Please enter 'y' or 'n'."
  exit 1
fi

# Get the directory path of the script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Change to the script's directory
cd "$script_dir"

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
        fi
    else
        echo "$package_name is already installed."
    fi
}

check_installation "openssl"
check_installation "unzip"
check_installation "mokutil"
check_installation "efitools"

efikeys_dir="$script_dir/efikeys"
if [ ! -d "$efikeys_dir" ]; then
  mkdir "$efikeys_dir"
  echo "Created efikeys directory"
else
  echo "efikeys directory already exists"
fi

# Check if the files already exist before creating them
if [[ ! -f $efikeys_dir/PK.key && ! -f $efikeys_dir/PK.pem ]]; then
    openssl req -new -x509 -newkey rsa:2048 -sha256 -nodes -subj "/CN=OpenCore PK Platform Key/" -keyout $efikeys_dir/PK.key -out $efikeys_dir/PK.pem
    chmod 0600 $efikeys_dir/PK.key
fi

if [[ ! -f $efikeys_dir/KEK.key && ! -f $efikeys_dir/KEK.pem ]]; then
    openssl req -new -x509 -newkey rsa:2048 -sha256 -nodes -subj "/CN=OpenCore KEK Exchange Key/" -keyout $efikeys_dir/KEK.key -out $efikeys_dir/KEK.pem
    chmod 0600 $efikeys_dir/KEK.key
fi

if [[ ! -f $efikeys_dir/ISK.key && ! -f $efikeys_dir/ISK.pem ]]; then
    openssl req -new -x509 -newkey rsa:2048 -sha256 -nodes -subj "/CN=OpenCore ISK Image Signing Key/" -keyout $efikeys_dir/ISK.key -out $efikeys_dir/ISK.pem
    chmod 0600 $efikeys_dir/ISK.key
fi

# Check if the Microsoft certificates already exist before downloading them
if [[ ! -f $efikeys_dir/MicWinProPCA2011_2011-10-19.crt && ! -f $efikeys_dir/MicWinProPCA2011_2011-10-19.pem ]]; then
    curl -o $efikeys_dir/MicWinProPCA2011_2011-10-19.crt https://www.microsoft.com/pkiops/certs/MicWinProPCA2011_2011-10-19.crt
    openssl x509 -in $efikeys_dir/MicWinProPCA2011_2011-10-19.crt -inform DER -out $efikeys_dir/MicWinProPCA2011_2011-10-19.pem -outform PEM
fi

if [[ ! -f $efikeys_dir/MicCorUEFCA2011_2011-06-27.crt && ! -f $efikeys_dir/MicCorUEFCA2011_2011-06-27.pem ]]; then
    curl -o $efikeys_dir/MicCorUEFCA2011_2011-06-27.crt https://www.microsoft.com/pkiops/certs/MicCorUEFCA2011_2011-06-27.crt
    openssl x509 -in $efikeys_dir/MicCorUEFCA2011_2011-06-27.crt -inform DER -out $efikeys_dir/MicCorUEFCA2011_2011-06-27.pem -outform PEM
fi

# Check if the EFI signature list files already exist before creating them
if [[ ! -f $efikeys_dir/PK.esl ]]; then
    cert-to-efi-sig-list -g $(uuidgen) $efikeys_dir/PK.pem $efikeys_dir/PK.esl
fi

if [[ ! -f $efikeys_dir/KEK.esl ]]; then
    cert-to-efi-sig-list -g $(uuidgen) $efikeys_dir/KEK.pem $efikeys_dir/KEK.esl
fi

if [[ ! -f $efikeys_dir/ISK.esl ]]; then
    cert-to-efi-sig-list -g $(uuidgen) $efikeys_dir/ISK.pem $efikeys_dir/ISK.esl
fi

if [[ ! -f $efikeys_dir/MicWinProPCA2011_2011-10-19.esl ]]; then
    cert-to-efi-sig-list -g $(uuidgen) $efikeys_dir/MicWinProPCA2011_2011-10-19.pem $efikeys_dir/MicWinProPCA2011_2011-10-19.esl
fi

if [[ ! -f $efikeys_dir/MicCorUEFCA2011_2011-06-27.esl ]]; then
    cert-to-efi-sig-list -g $(uuidgen) $efikeys_dir/MicCorUEFCA2011_2011-06-27.pem $efikeys_dir/MicCorUEFCA2011_2011-06-27.esl
fi

# Check if db.esl already exists and skip creation
if [[ -f $efikeys_dir/db.esl ]]; then
    echo "The file 'db.esl' already exists. Skipping creation."
else
    cat $efikeys_dir/PK.esl $efikeys_dir/KEK.esl $efikeys_dir/ISK.esl $efikeys_dir/MicWinProPCA2011_2011-10-19.esl $efikeys_dir/MicCorUEFCA2011_2011-06-27.esl > $efikeys_dir/db.esl
fi

# Check if .auth files already exist and skip creation
if [[ -f $efikeys_dir/PK.auth ]]; then
    echo "The file 'PK.auth' already exists. Skipping creation."
else
    sign-efi-sig-list -k $efikeys_dir/PK.key -c $efikeys_dir/PK.pem PK $efikeys_dir/PK.esl $efikeys_dir/PK.auth
    echo "'PK.auth' created successfully."
fi

if [[ -f $efikeys_dir/KEK.auth ]]; then
    echo "The file 'KEK.auth' already exists. Skipping creation."
else
    sign-efi-sig-list -k $efikeys_dir/PK.key -c $efikeys_dir/PK.pem KEK $efikeys_dir/KEK.esl $efikeys_dir/KEK.auth
    echo "'KEK.auth' created successfully."
fi

if [[ -f $efikeys_dir/db.auth ]]; then
    echo "The file 'db.auth' already exists. Skipping creation."
else
    sign-efi-sig-list -k $efikeys_dir/KEK.key -c $efikeys_dir/KEK.pem db $efikeys_dir/db.esl $efikeys_dir/db.auth
    echo "'db.auth' created successfully."
fi

# Check if the 'Download' directory already exists and skip creation
if [[ -d "$script_dir/Download" ]]; then
    echo "The 'Download' directory already exists. Skipping creation."
else
    # Create working directory
    mkdir "$script_dir/Download"
    echo "Directory 'Download' created successfully."
fi

# Function to fetch the latest OpenCore version from GitHub
get_latest_version() {
  local url="https://api.github.com/repos/acidanthera/OpenCorePkg/releases/latest"
  local response=$(curl -s "$url")
  local version=$(echo "$response" | grep -oP '"tag_name": "\K(.*)(?=")')
  echo "$version"
}

# Fetch the latest OpenCore version
latest_version=$(get_latest_version)

# Set the download link
LINK="https://github.com/acidanthera/OpenCorePkg/releases/download/${latest_version}/OpenCore-${latest_version}-RELEASE.zip"

# Define the target directory for extraction
target_directory="$script_dir/Download"

# Check if OpenCore has already been downloaded
if [ -d "$target_directory/X64" ] && [ -d "$target_directory/Docs" ] && [ -d "$target_directory/Utilities" ]; then
  echo "OpenCore is already downloaded."
else
  # Download and unzip OpenCore
  curl -O "$target_directory/OpenCore-$latest_version-RELEASE.zip" "$LINK"
  unzip "$target_directory/OpenCore-$latest_version-RELEASE.zip" "X64/*" -d "$target_directory"
  unzip "$target_directory/OpenCore-$latest_version-RELEASE.zip" "Docs/*" -d "$target_directory"
  unzip "$target_directory/OpenCore-$latest_version-RELEASE.zip" "Utilities/*" -d "$target_directory"
  echo "OpenCore downloaded and extracted successfully."
fi

mkdir -p "$script_dir/system-files"
# Source folder
src_folder="$script_dir/system-files"
# Destination folder
dest_folder="$script_dir/Download/X64/EFI/OC"
# Copy files with overwrite
cp -r -f "$src_folder"/* "$dest_folder"

# Check ISK files
if [ -f "$efikeys_dir/ISK.key" ]; then
    echo "ISK.key was decrypted successfully"
fi

if [ -f "$efikeys_dir/ISK.pem" ]; then
    echo "ISK.pem was decrypted successfully"
fi

# Create the X64-Signed directory
if [ -d "$target_directory/X64-Signed" ]; then
  rm -rf "$target_directory/X64-Signed"
fi
mkdir -p "$target_directory/X64-Signed"
X64_Signed="$target_directory/X64-Signed"

# Source folder
src_folder="$target_directory/X64"
# Destination folder
dest_folder="$target_directory/X64-Signed"
# Copy files with overwrite
cp -r -f "$src_folder"/* "$dest_folder"

# Specify key & PEM certificate files
key="$efikeys_dir/ISK.key"
pem_certificate="$efikeys_dir/ISK.pem"

# Sign .kext, .aml, and .efi files in the X64-Signed directory and subdirectories
find "$X64_Signed" \( -name "*.kext" -o -name "*.aml" -o -name "*.efi" \) -type f | while read -r file; do
    # Sign the file using sbsign and override the original file
    sbsign --key "$key" --cert "$pem_certificate" --output "$file" "$file"
done

# Find the EFI partition
efi_partition=$(findmnt -n -o SOURCE -T /boot/efi)

# Function to install OpenCore without secure boot
install_without_secure_boot() {
  echo "Installing OpenCore without secure boot..."
  # Mount the EFI partition
  sudo mount "$efi_partition" /mnt
  # Copy files from X64-Signed folder to the EFI partition
  sudo cp -R "$target_directory/X64"* /mnt
  # Unmount the EFI partition
  sudo umount /mnt
}

# Function to install OpenCore with secure boot
install_with_secure_boot() {
  echo "Installing OpenCore with secure boot..."
  # add .auth files into uefi firmware
  sudo mokutil --import $efikeys_dir/PK.auth
  sudo mokutil --import $efikeys_dir/KEK.auth
  sudo mokutil --import $efikeys_dir/db.auth
  # Mount the EFI partition
  sudo mount "$efi_partition" /mnt
  # Copy files from X64-Signed folder to the EFI partition
  sudo cp -R "$target_directory/X64-Signed"* /mnt
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

# Clean up
rm "$target_directory/OpenCore-$latest_version-RELEASE.zip" 2>/dev/null
