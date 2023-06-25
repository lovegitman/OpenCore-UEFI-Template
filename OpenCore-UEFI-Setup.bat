@echo off

REM Check if running with administrative privileges
net session >nul 2>&1
if %errorLevel% EQU 0 (
    echo Running with administrative privileges.
) else (
    echo Restarting with administrative privileges...
    powershell.exe -Command "Start-Process -FilePath '%0' -Verb RunAs"
    exit /B
)

set "script_dir=%~dp0"
cd /d "%script_dir%"

REM Check if Chocolatey is installed
where choco > nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    REM Chocolatey not found, installing it
    echo Installing Chocolatey...

    REM Run PowerShell script to install Chocolatey
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"

    REM Check if installation was successful
    where choco > nul 2>&1
    IF %ERRORLEVEL% EQU 0 (
        echo Chocolatey installed successfully.
    ) ELSE (
        echo Failed to install Chocolatey.
        pause
        exit /b
    )
) ELSE (
    echo Chocolatey is already installed.
)

REM Check if OpenSSL is installed
where openssl > nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    REM OpenSSL not found, installing it
    echo Installing OpenSSL...

    REM Install OpenSSL using Chocolatey
    choco install openssl.light -y

    REM Check if installation was successful
    where openssl > nul 2>&1
    IF %ERRORLEVEL% EQU 0 (
        echo OpenSSL installed successfully.
    ) ELSE (
        echo Failed to install OpenSSL.
        pause
        exit /b
    )
) ELSE (
    echo OpenSSL is already installed.
)

REM Check if Osslsigncode is installed
where osslsigncode > nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    REM Osslsigncode not found, installing it
    echo Installing Osslsigncode...

    REM Install Osslsigncode using Chocolatey
    choco install osslsigncode -y

    REM Check if installation was successful
    where osslsigncode > nul 2>&1
    IF %ERRORLEVEL% EQU 0 (
        echo Osslsigncode installed successfully.
    ) ELSE (
        echo Failed to install Osslsigncode.
        pause
        exit /b
    )
) ELSE (
    echo Osslsigncode is already installed.
)

REM Check if Curl is installed
where curl > nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    REM Curl not found, installing it
    echo Installing Curl...

    REM Install Curl using Chocolatey
    choco install curl -y

    REM Check if installation was successful
    where curl > nul 2>&1
    IF %ERRORLEVEL% EQU 0 (
        echo Curl installed successfully.
    ) ELSE (
        echo Failed to install Curl.
        pause
        exit /b
    )
) ELSE (
    echo Curl is already installed.
)

REM Check if SecureBootUEFI module is installed
powershell.exe -NoProfile -Command "Get-Module SecureBootUEFI -ListAvailable" > nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo SecureBootUEFI module not found, installing it...

    REM Install SecureBootUEFI module using PowerShell Gallery
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Install-Module -Name SecureBootUEFI -Scope CurrentUser -Force"

    REM Check if installation was successful
    powershell.exe -NoProfile -Command "Get-Module SecureBootUEFI -ListAvailable" > nul 2>&1
    IF %ERRORLEVEL% EQU 0 (
        echo SecureBootUEFI module installed successfully.
    ) ELSE (
        echo Failed to install SecureBootUEFI module.
        pause
        exit /b
    )
) ELSE (
    echo SecureBootUEFI module is already installed.
)

set "efikeys_dir=%script_dir%\efikeys"
if not exist "%efikeys_dir%" (
  mkdir "%efikeys_dir%"
)

set "download_dir=%script_dir%\Download"
if not exist "%download_dir%" (
  mkdir "%download_dir%"
)

set "system_dir=%script_dir%\system-files"
if not exist "%system_dir%" (
  mkdir "%system_dir%"
)

set "X64=%script_dir%\Download\X64"
set "X64_Signed=%script_dir%\Download\X64-Signed"

REM create certificate and key

REM Create PK (Platform Key)
if not exist "%efikeys_dir%\PK.key" (
    del "%efikeys_dir%\PK.key" 2>nul
    del "%efikeys_dir%\PK.pem" 2>nul
    openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes -subj "/CN=OpenCore PK Platform Key/" -keyout "%efikeys_dir%\PK.key" -out "%efikeys_dir%\PK.pem" -outform PEM
)

REM Create KEK (Key Exchange Key)
if not exist "%efikeys_dir%\KEK.key" (
    del "%efikeys_dir%\KEK.key" 2>nul
    del "%efikeys_dir%\KEK.pem" 2>nul
    openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes -subj "/CN=OpenCore KEK Exchange Key/" -keyout "%efikeys_dir%\KEK.key" -out "%efikeys_dir%\KEK.pem" -outform PEM
)

REM Create ISK (Initial Supplier Key)
if not exist "%efikeys_dir%\ISK.key" (
    del "%efikeys_dir%\ISK.key" 2>nul
    del "%efikeys_dir%\ISK.pem" 2>nul
    openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes -subj "/CN=OpenCore ISK Image Signing Key/" -keyout "%efikeys_dir%\ISK.key" -out "%efikeys_dir%\ISK.pem" -outform PEM
)

REM Permission for key files
attrib +r "%efikeys_dir%\*.key"

REM Convert PEM files to ESL format suitable for UEFI Secure Boot
if not exist "%efikeys_dir%\PK.esl" (
    certutil -encode "%efikeys_dir%\PK.pem" "%efikeys_dir%\PK.esl"
)
if not exist "%efikeys_dir%\KEK.esl" (
    certutil -encode "%efikeys_dir%\KEK.pem" "%efikeys_dir%\KEK.esl"
)
if not exist "%efikeys_dir%\ISK.esl" (
    certutil -encode "%efikeys_dir%\ISK.pem" "%efikeys_dir%\ISK.esl"
)

REM Create the database
if not exist "%efikeys_dir%\db.esl" (
    copy /b "%efikeys_dir%\ISK.esl" "%efikeys_dir%\db.esl"
)

REM Digitally sign ESL files
REM PK sign
if not exist "%efikeys_dir%\PK.auth" (
    openssl x509 -in "%efikeys_dir%\PK.pem" -outform der -out "%efikeys_dir%\PK.auth"
    type "%efikeys_dir%\PK.key" >> "%efikeys_dir%\PK.auth"
    type "%efikeys_dir%\PK.esl" >> "%efikeys_dir%\PK.auth"
)
REM KEK is signed with PK
if not exist "%efikeys_dir%\KEK.auth" (
    openssl x509 -in "%efikeys_dir%\PK.pem" -outform der -out "%efikeys_dir%\KEK.auth"
    type "%efikeys_dir%\PK.key" >> "%efikeys_dir%\KEK.auth"
    type "%efikeys_dir%\KEK.esl" >> "%efikeys_dir%\KEK.auth"
)
REM the database is signed with KEK
if not exist "%efikeys_dir%\db.auth" (
    openssl x509 -in "%efikeys_dir%\KEK.pem" -outform der -out "%efikeys_dir%\db.auth"
    type "%efikeys_dir%\KEK.key" >> "%efikeys_dir%\db.auth"
    type "%efikeys_dir%\db.esl" >> "%efikeys_dir%\db.auth"
)

set ISK_key="%efikeys_dir%\ISK.key"
set ISK_pem="%efikeys_dir%\ISK.pem"

if exist "%download_dir%\X64" if exist "%download_dir%\Docs" if exist "%download_dir%\Utilities" (
  echo All three directories (X64, Docs, Utilities) exist.
  rem Add your desired code here when all directories exist
) else (
  echo One or more directories are missing.
  rem Define the GitHub repository
  set "repository=acidanthera/OpenCorePkg"
  rem Get the latest release information from the GitHub API
  for /f "usebackq delims=" %%G in (`curl.exe -s "https://api.github.com/repos/%repository%/releases/latest"`) do set "release_info=%%G"
  rem Filter out debug assets using PowerShell
  for /f "usebackq tokens=2 delims=: " %%G in (`echo %%release_info%% ^| powershell -Command "$json = ConvertFrom-Json -InputObject (Get-Content -Raw); $json.assets | Where-Object { $_.name -notmatch 'DEBUG' } | Select-Object -First 1 -ExpandProperty browser_download_url"`) do set "download_url=%%G"
  rem Extract the file name from the download URL
  for %%G in ("%download_url%") do set "file_name=%%~nG"
  rem Define the destination file path
  set "destination_path=%download_dir%\%file_name%"
  rem Download the latest OpenCore zip file
  curl.exe -L -o "%destination_path%" "%download_url%"
  rem Check if X64 directory is missing
  if not exist "%download_dir%\X64" (
    rem Unzip X64 directory from OpenCore
    powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%destination_path%', '%download_dir%'); $folderPath = Join-Path '%download_dir%' 'X64'"
  )
  rem Check if Docs directory is missing
  if not exist "%download_dir%\Docs" (
    rem Unzip Docs directory from OpenCore
    powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%destination_path%', '%download_dir%'); $folderPath = Join-Path '%download_dir%' 'Docs'"
  )
  rem Check if Utilities directory is missing
  if not exist "%download_dir%\Utilities" (
    rem Unzip Utilities directory from OpenCore
    powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%destination_path%', '%download_dir%'); $folderPath = Join-Path '%download_dir%' 'Utilities'"
  )
  rem Clean up
  del "%destination_path%" 2>nul
)

REM Source folder
set "src_folder=%system_dir%"
REM Destination folder
set "dest_folder=%download_dir%\X64\EFI\OC"
REM Copy files with overwrite
xcopy /E /Y "%src_folder%\*" "%dest_folder%"

REM Create the X64-Signed directory
if exist "%X64_Signed%" (
  rmdir /S /Q "%X64_Signed%"
)
mkdir "%X64_Signed%"

REM Source folder
set "src_folder=%X64%"
REM Destination folder
set "dest_folder=%X64_Signed%"
REM Copy files with overwrite
xcopy /E /Y "%src_folder%\*" "%dest_folder%"

REM Sign .efi .kext files in X64-Signed directory and subdirectories
for /r %X64_Signed% %%F in (*.efi, *.kext) do (
    rem Sign the file using osslsigncode and override the original file
    osslsigncode sign -cert "%ISK_pem%" -key "%ISK_key%" -h sha256 -n "OpenCore ISK Image Signing Key" -in "%%F" -out "%%F"
)

REM Function to install OpenCore without secure boot
:install_without_secure_boot
REM Find the EFI partition
for /f "tokens=2 delims==" %%I in ('wmic volume where "BootVolume=true" get DeviceID /value') do set "efi_partition=%%I"
REM Mount the EFI partition
mountvol %efi_partition% /d
mountvol %efi_partition% /s
REM Copy files from X64-Signed folder to the EFI partition
xcopy /E /I /Y "%download_dir%\X64" "%efi_partition%\EFI\OC"
REM Set the description for the boot option
set "BOOT_OPTION_DESC=Opencore Bootloader"
REM Set the path to the Opencore bootloader in the EFI partition
set "EFI_PATH=\EFI\OC\OpenCore.efi"
REM Check if the boot option already exists
set "existing_boot_option="
for /f "tokens=*" %%A in ('bcdedit /enum firmware') do (
  echo %%A | findstr /i "%BOOT_OPTION_DESC%" >nul
  if not errorlevel 1 set "existing_boot_option=1"
)
if "%existing_boot_option%"=="1" (
  echo Opencore boot option already exists.
) else (
  REM Add the boot option using bcdedit
  bcdedit /create /d "%BOOT_OPTION_DESC%" /application bootsector
  for /f "tokens=2 delims={}" %%B in ('bcdedit /enum firmware ^| findstr /i "{bootmgr}"') do set "bootmgr_guid=%%B"
  bcdedit /set %bootmgr_guid% description "%BOOT_OPTION_DESC%"
  bcdedit /set %bootmgr_guid% path "%EFI_PATH%"
  bcdedit /displayorder %bootmgr_guid% /addlast
)
REM Unmount the EFI partition
mountvol %efi_partition% /d

goto :end

REM Function to install OpenCore with secure boot
:install_with_secure_boot
REM add .auth files into uefi firmware
REM Check if the PK.auth file is already imported
powershell -Command "& { if (Test-SecureBootUEFIFirmware -PKAuthFile '%efikeys_dir%\PK.auth') { exit 0 } else { exit 1 } }"
if "%errorlevel%"=="1" (
  powershell -Command "& { Import-SecureBootUEFIFirmware -PKAuthFile '%efikeys_dir%\PK.auth' }"
)
REM Check if the KEK.auth file is already imported
powershell -Command "& { if (Test-SecureBootUEFIFirmware -KEKAuthFile '%efikeys_dir%\KEK.auth') { exit 0 } else { exit 1 } }"
if "%errorlevel%"=="1" (
  powershell -Command "& { Import-SecureBootUEFIFirmware -KEKAuthFile '%efikeys_dir%\KEK.auth' }"
)
REM Check if the db.auth file is already imported
powershell -Command "& { if (Test-SecureBootUEFIFirmware -DBAuthFile '%efikeys_dir%\db.auth') { exit 0 } else { exit 1 } }"
if "%errorlevel%"=="1" (
  powershell -Command "& { Import-SecureBootUEFIFirmware -DBAuthFile '%efikeys_dir%\db.auth' }"
)
REM Find the EFI partition
for /f "tokens=2 delims==" %%I in ('wmic volume where "BootVolume=true" get DeviceID /value') do set "efi_partition=%%I"
REM Mount the EFI partition
mountvol %efi_partition% /d
mountvol %efi_partition% /s
REM Copy files from X64-Signed folder to the EFI partition
xcopy /E /I /Y "%download_dir%\X64-Signed" "%efi_partition%\EFI\OC"
REM Set the description for the boot option
set "BOOT_OPTION_DESC=Opencore Bootloader"
REM Set the path to the Opencore bootloader in the EFI partition
set "EFI_PATH=\EFI\OC\OpenCore.efi"
REM Check if the boot option already exists
set "existing_boot_option="
for /f "tokens=*" %%A in ('bcdedit /enum firmware') do (
  echo %%A | findstr /i "%BOOT_OPTION_DESC%" >nul
  if not errorlevel 1 set "existing_boot_option=1"
)
if "%existing_boot_option%"=="1" (
  echo Opencore boot option already exists.
) else (
  REM Add the boot option using bcdedit
  bcdedit /create /d "%BOOT_OPTION_DESC%" /application bootsector
  for /f "tokens=2 delims={}" %%B in ('bcdedit /enum firmware ^| findstr /i "{bootmgr}"') do set "bootmgr_guid=%%B"
  bcdedit /set %bootmgr_guid% description "%BOOT_OPTION_DESC%"
  bcdedit /set %bootmgr_guid% path "%EFI_PATH%"
  bcdedit /displayorder %bootmgr_guid% /addlast
)
REM Unmount the EFI partition
mountvol %efi_partition% /d

goto :end

REM Prompt user for installation type
echo OpenCore Installation
echo ---------------------
echo Please select the installation type:
echo 1. Install with secure boot
echo 2. Install without secure boot
echo 3. Do not install OpenCore
echo BEFORE INSTALL MUST MODIFY system-files FOLDER FOR YOUR SYSTEM
echo anything inside system-files will be added to Download\X64\EFI\OC\
set /p "choice=Enter your choice (1, 2, or 3): "

REM Validate the user's choice and execute the appropriate function
if "%choice%"=="1" (
  call :install_with_secure_boot
) else if "%choice%"=="2" (
  call :install_without_secure_boot
) else if "%choice%"=="3" (
  echo Skipping OpenCore installation.
) else (
  echo Invalid choice. Please select 1, 2, or 3.
)

:end
