# -OpenCore-UEFI-Template

automates the process of generating EFI keys and installing OpenCore on your system

1. Checks internet connectivity and updates DNS configuration if needed.
2. Installs required packages (openssl, unzip, mokutil, efitools) if not already installed.
3. Generates EFI keys (PK, KEK, ISK) using OpenSSL.
4. Downloads Microsoft certificates for EFI signature verification.
5. Generates EFI signature list files (PK, KEK, ISK, Microsoft certificates).
6. Creates the 'db.esl' file by combining all EFI signature list files.
7. Signs EFI signature list files using the respective keys to generate '.auth' files.
8. Downloads the latest OpenCore version from the official GitHub repository.
9. Extracts the OpenCore archive and copies necessary files to the EFI partition.
10. Signs the OpenCore EFI binaries with the ISK key if available.
11. Installs OpenCore on the EFI partition either with or without secure boot.

## Prerequisites
Before running the script, ensure that you have the following:
- Internet connectivity.
- Appropriate permissions to modify system files.
- Basic knowledge of EFI, OpenCore, and system booting.
- For Ubuntu & Fedora Based Linux Distro

## Usage
1. chmod +x OpenCore-UEFI-Setup.sh && ./OpenCore-UEFI-Setup.sh
2. WHEN ASKED DO NOT INSTALL OPENCORE YOU MUST MODIFY system-files FOLDER FOR YOUR SYSTEM  
(anything in system-files folder will be copied into Download/X64/EFI/OC/ folder overriding files)  
3. Re-Run Shell Script: ./OpenCore-UEFI-Setup.sh  
(Re-Running Shell Script won't delete files created)  
4. You Now Can Install OpenCore on your system  
