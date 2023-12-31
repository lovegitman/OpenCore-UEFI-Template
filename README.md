# OpenCore-UEFI-Template  
It is recommended to have a backup of your system before installing OpenCore.  

automates the process of installing OpenCore on your system

Linux:
1. Checks if required packages (openssl, unzip, mokutil, efitools, curl) are installed and if necessary directories and files exist.
2. Installs any missing packages using APT or DNF package managers.
3. Creates necessary directories for the script to work.
4. Downloads the latest release of OpenCore from a GitHub repository and extracts necessary directories (X64, Docs, Utilities).
5. Copies system files to the appropriate destination.
6. Creates a signed version of the X64 directory by signing the .efi .kext files using sbsign.
7. Provides options for installing OpenCore with or without secure boot.
8. Installs OpenCore by copying files to the EFI partition.

## Prerequisites
Before running script, ensure that you have the following:
- Internet connectivity.
- Appropriate permissions to modify system files.
- Basic knowledge of EFI, OpenCore, and system booting.
- For Ubuntu & Fedora Based Linux Distro or Windows
- For X64 Computer
  
## Usage
Linux:
1. chmod +x OpenCore-UEFI-Setup.sh && ./OpenCore-UEFI-Setup.sh
2. WHEN ASKED DO NOT INSTALL OPENCORE YOU MUST MODIFY system-files FOLDER FOR YOUR SYSTEM  
(anything in system-files folder will be copied into Download/X64/EFI/OC/ folder overriding files)  
3. Re-Run Shell Script: ./OpenCore-UEFI-Setup.sh  
4. You Now Can Install OpenCore on your system  
can't install in  Windows Subsystem for Linux (WSL)  

```xml
Adding Secure Boot Support:  
The RequireSignature key enables the requirement for signed bootloaders and kernel extensions (kexts).  
Setting it to <true/> ensures that only signed components are loaded.  

The RequireVault key enables the requirement for a vaulted configuration, which provides additional security measures. Setting it to <true/> ensures that the configuration is vaulted.  

The ScanPolicy key sets the policy for scanning unsigned drivers during boot. Setting it to <integer>0</integer> allows all drivers to load regardless of their signatures. You can change this value if you want to enforce stricter policies.  

Open your config.plist (system-files/config.plist) file using a text editor.  

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
<plist version="1.0">
<dict>
    <!-- Other sections and settings -->

    <key>PlatformInfo</key>
    <dict>
        <!-- Other settings -->

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

        <!-- Other settings -->

    </dict>

    <!-- Other sections and settings -->

</dict>
</plist>

