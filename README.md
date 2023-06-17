# OpenCore-UEFI-Template  
It is recommended to have a backup of your system before installing OpenCore.  

automates the process of installing OpenCore on your system

Linux:
1. Checks if required packages (openssl, unzip, mokutil, efitools, curl) are installed and if necessary directories and files exist.
2. Installs any missing packages using APT or DNF package managers.
3. Creates necessary directories for the script to work.
4. Downloads Microsoft certificates and converts them to suitable formats.
5. Downloads the latest release of OpenCore from a GitHub repository and extracts necessary directories (X64, Docs, Utilities).
6. Copies system files to the appropriate destination.
7. Creates a signed version of the X64 directory by signing the .efi files using sbsign.
8. Provides options for installing OpenCore with or without secure boot.
9. Installs OpenCore by copying files to the EFI partition.

## Prerequisites
Before running script, ensure that you have the following:
- Internet connectivity.
- Appropriate permissions to modify system files.
- Basic knowledge of EFI, OpenCore, and system booting.
- For Ubuntu & Fedora Based Linux Distro or Windows (coming soon)

## Usage
Linux:
1. chmod +x OpenCore-UEFI-Setup.sh && ./OpenCore-UEFI-Setup.sh
2. WHEN ASKED DO NOT INSTALL OPENCORE YOU MUST MODIFY system-files FOLDER FOR YOUR SYSTEM  
(anything in system-files folder will be copied into Download/X64/EFI/OC/ folder overriding files)  
3. Re-Run Shell Script: ./OpenCore-UEFI-Setup.sh  
(Re-Running Shell Script won't delete files created)  
4. You Now Can Install OpenCore on your system  
can't install in  Windows Subsystem for Linux (WSL)  

windows:  
coming soon  

```xml
Adding Secure Boot Support:  
add UEFI Secure Boot support to your OpenCore config.plist file (system-files/config.plist)  
Locate the "Misc" section in the file. If it doesn't exist, add the following code to create it:  
<key>Misc</key>
<dict>
</dict>

Inside the "Misc" section, add the following code to enable UEFI Secure Boot:
<key>Security</key>
<dict>
    <key>RequireSignature</key>
    <true/>
    <key>RequireVault</key>
    <true/>
    <key>ScanPolicy</key>
    <integer>0</integer>
</dict>

should look like:
<key>Misc</key>
<dict>
    <key>Security</key>
    <dict>
        <key>RequireSignature</key>
        <true/>
        <key>RequireVault</key>
        <true/>
        <key>ScanPolicy</key>
        <integer>0</integer>
    </dict>
</dict>
