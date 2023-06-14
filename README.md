# OpenCore-UEFI-Template  
It is recommended to have a backup of your system before installing OpenCore.  

automates the process of generating EFI keys and installing OpenCore on your system  

1. Checks internet connectivity
2. Automated Dependency Installation
3. Generates EFI keys (PK, KEK, ISK) using OpenSSL.
4. Downloads Microsoft certificates for EFI signature verification.
5. Generates EFI signature list files (PK, KEK, ISK, Microsoft certificates).
6. Creates the 'db.esl' file by combining all EFI signature list files.
7. Signs EFI signature list files using the respective keys to generate '.auth' files.
8. Downloads the latest OpenCore version from the official GitHub repository.
9. Signs the OpenCore EFI binaries with the ISK key if available.
10. Installs OpenCore on the EFI partition either with or without secure boot.  

## Prerequisites
Before running script, ensure that you have the following:
- Internet connectivity.
- Appropriate permissions to modify system files.
- Basic knowledge of EFI, OpenCore, and system booting.
- For Ubuntu & Fedora Based Linux Distro or Windows

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
1. run OpenCore-UEFI-Setup.bat
2. Answer the prompt regarding internet connectivity.
3. The script automatically installs or updates required tools.
4. EFI keys, certificates, Microsoft certificates, EFI signature list files, and authorization files are generated or downloaded as needed
5. The script creates a "Download" directory and downloads the latest OpenCore version
6. will ask to install opencore on your system  
YOU MUST MODIFY system-files FOLDER FOR YOUR SYSTEM

Adding Secure Boot Support:
add UEFI Secure Boot support to your OpenCore config.plist file (system-files/config.plist)
Locate the "Misc" section in the file. If it doesn't exist, add the following code to create it:
<key>Misc</key>
<dict>
</dict>

Inside the "Misc" section, add the following code to enable UEFI Secure Boot:
<key>Security</key>
<dict>
    <key>SecureBootModel</key>
    <string>Default</string>
    <key>ScanPolicy</key>
    <integer>0</integer>
</dict>

The "SecureBootModel" key specifies the Secure Boot model to use. "Default" is a commonly used value, but you can change it if needed. The "ScanPolicy" key sets the policy for scanning and verifying UEFI bootloaders and drivers. A value of "0" disables scanning, allowing all UEFI binaries to be executed.
