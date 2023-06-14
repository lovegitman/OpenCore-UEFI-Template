@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Check if running with admin rights
net session >nul 2>nul
if %errorlevel% equ 0 (
    echo Running with administrator privileges.
) else (
    echo Re-running with administrator privileges...
    REM Re-run the script with admin rights
    powershell -Command "Start-Process -Verb RunAs -FilePath '%0' -ArgumentList '%*'"
    exit /b
)

set /p answer="Are you connected to the internet? (y/n): "
set answer=%answer:~0,1%
set answer=%answer:~0,1%
if "%answer%"=="y" (
  echo Internet is available.
) else if "%answer%"=="n" (
  echo Connect to the internet and try again.
  exit /b 1
) else (
  echo Invalid input. Please enter 'y' or 'n'.
  exit /b 1
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
    )
) ELSE (
    echo OpenSSL is already installed.
)

REM Check if signtool is already installed
where signtool >nul 2>nul
if %errorlevel% equ 0 (
    echo signtool is already installed.
) else (
    echo Installing signtool...
    REM Install signtool using Chocolatey
    choco install signtool -y
    if %errorlevel% neq 0 (
        echo Failed to install signtool using Chocolatey.
        exit /b 1
    )
    echo signtool has been installed successfully.
)

REM Check if curl is installed
where curl >nul 2>nul
if %errorlevel% equ 0 (
    echo curl is already installed.
) else (
    echo Installing curl...
    REM Install curl using Chocolatey
    choco install curl -y
    if %errorlevel% neq 0 (
        echo Failed to install curl using Chocolatey.
        exit /b 1
    )
    echo curl has been installed successfully.
)

set "efikeys_dir=%script_dir%efikeys"
if not exist "%efikeys_dir%" (
    mkdir "%efikeys_dir%"
    echo Created efikeys directory.
) else (
    echo efikeys directory already exists.
)

REM Check if the files already exist before creating them
if not exist "%efikeys_dir%\PK.key" if not exist "%efikeys_dir%\PK.pem" (
    openssl req -new -x509 -newkey rsa:2048 -sha256 -nodes -subj "/CN=OpenCore PK Platform Key/" -keyout "%efikeys_dir%\PK.key" -out "%efikeys_dir%\PK.pem"
    icacls "%efikeys_dir%\PK.key" /inheritance:r
    icacls "%efikeys_dir%\PK.key" /grant:r "SYSTEM:(F)"
    icacls "%efikeys_dir%\PK.key" /grant:r "%USERNAME%:(F)"
)

if not exist "%efikeys_dir%\KEK.key" if not exist "%efikeys_dir%\KEK.pem" (
    openssl req -new -x509 -newkey rsa:2048 -sha256 -nodes -subj "/CN=OpenCore KEK Exchange Key/" -keyout "%efikeys_dir%\KEK.key" -out "%efikeys_dir%\KEK.pem"
    icacls "%efikeys_dir%\KEK.key" /inheritance:r
    icacls "%efikeys_dir%\KEK.key" /grant:r "SYSTEM:(F)"
    icacls "%efikeys_dir%\KEK.key" /grant:r "%USERNAME%:(F)"
)

if not exist "%efikeys_dir%\ISK.key" if not exist "%efikeys_dir%\ISK.pem" (
    openssl req -new -x509 -newkey rsa:2048 -sha256 -nodes -subj "/CN=OpenCore ISK Image Signing Key/" -keyout "%efikeys_dir%\ISK.key" -out "%efikeys_dir%\ISK.pem"
    icacls "%efikeys_dir%\ISK.key" /inheritance:r
    icacls "%efikeys_dir%\ISK.key" /grant:r "SYSTEM:(F)"
    icacls "%efikeys_dir%\ISK.key" /grant:r "%USERNAME%:(F)"
)

REM Check if the Microsoft certificates already exist before downloading them
if not exist "%efikeys_dir%\MicWinProPCA2011_2011-10-19.crt" if not exist "%efikeys_dir%\MicWinProPCA2011_2011-10-19.pem" (
    curl -o "%efikeys_dir%\MicWinProPCA2011_2011-10-19.crt" https://www.microsoft.com/pkiops/certs/MicWinProPCA2011_2011-10-19.crt
    openssl x509 -in "%efikeys_dir%\MicWinProPCA2011_2011-10-19.crt" -inform DER -out "%efikeys_dir%\MicWinProPCA2011_2011-10-19.pem" -outform PEM
)

if not exist "%efikeys_dir%\MicCorUEFCA2011_2011-06-27.crt" if not exist "%efikeys_dir%\MicCorUEFCA2011_2011-06-27.pem" (
    curl -o "%efikeys_dir%\MicCorUEFCA2011_2011-06-27.crt" https://www.microsoft.com/pkiops/certs/MicCorUEFCA2011_2011-06-27.crt
    openssl x509 -in "%efikeys_dir%\MicCorUEFCA2011_2011-06-27.crt" -inform DER -out "%efikeys_dir%\MicCorUEFCA2011_2011-06-27.pem" -outform PEM
)

REM Check if the EFI signature list files already exist before creating them
if not exist "%efikeys_dir%\PK.esl" (
    set "guid=%random%%random%%random%%random%"
    signtool sign /guid %guid% /n "PK.pem" /esl "%efikeys_dir%\PK.esl"
)

if not exist "%efikeys_dir%\KEK.esl" (
    set "guid=%random%%random%%random%%random%"
    signtool sign /guid %guid% /n "KEK.pem" /esl "%efikeys_dir%\KEK.esl"
)

if not exist "%efikeys_dir%\ISK.esl" (
    set "guid=%random%%random%%random%%random%"
    signtool sign /guid %guid% /n "ISK.pem" /esl "%efikeys_dir%\ISK.esl"
)

if not exist "%efikeys_dir%\MicWinProPCA2011_2011-10-19.esl" (
    set "guid=%random%%random%%random%%random%"
    signtool sign /guid %guid% /n "MicWinProPCA2011_2011-10-19.pem" /esl "%efikeys_dir%\MicWinProPCA2011_2011-10-19.esl"
)

if not exist "%efikeys_dir%\MicCorUEFCA2011_2011-06-27.esl" (
    set "guid=%random%%random%%random%%random%"
    signtool sign /guid %guid% /n "MicCorUEFCA2011_2011-06-27.pem" /esl "%efikeys_dir%\MicCorUEFCA2011_2011-06-27.esl"
)

REM Check if db.esl already exists and skip creation
if exist "%efikeys_dir%\db.esl" (
    echo "The file 'db.esl' already exists. Skipping creation."
) else (
    type "%efikeys_dir%\PK.esl" "%efikeys_dir%\KEK.esl" "%efikeys_dir%\ISK.esl" "%efikeys_dir%\MicWinProPCA2011_2011-10-19.esl" "%efikeys_dir%\MicCorUEFCA2011_2011-06-27.esl" > "%efikeys_dir%\db.esl"
)

REM Check if PK.auth file already exists and skip creation
if exist "%pk_auth%" (
    echo The file 'PK.auth' already exists. Skipping creation.
) else (
    signtool.exe sign /f "%pk_key%" /p "%pk_cert%" /d "PK" /du "PK" /n "PK" /t "http://timestamp.digicert.com" /v "%pk_esl%" "%pk_auth%"
    echo 'PK.auth' created successfully.
)

REM Check if KEK.auth file already exists and skip creation
if exist "%kek_auth%" (
    echo The file 'KEK.auth' already exists. Skipping creation.
) else (
    signtool.exe sign /f "%pk_key%" /p "%pk_cert%" /d "KEK" /du "KEK" /n "KEK" /t "http://timestamp.digicert.com" /v "%kek_esl%" "%kek_auth%"
    echo 'KEK.auth' created successfully.
)

REM Check if db.auth file already exists and skip creation
if exist "%db_auth%" (
    echo The file 'db.auth' already exists. Skipping creation.
) else (
    signtool.exe sign /f "%kek_key%" /p "%kek_cert%" /d "db" /du "db" /n "db" /t "http://timestamp.digicert.com" /v "%db_esl%" "%db_auth%"
    echo 'db.auth' created successfully.
)

REM Check if the 'Download' directory already exists and skip creation
if exist "%script_dir%\Download" (
    echo The 'Download' directory already exists. Skipping creation.
) else (
    mkdir "%script_dir%\Download"
    echo Directory 'Download' created successfully.
)

REM Function to fetch the latest OpenCore version from GitHub
:get_latest_version
set "url=https://api.github.com/repos/acidanthera/OpenCorePkg/releases/latest"
for /F "usebackq delims=" %%G in (`curl -s "%url%"`) do (
    set "response=%%G"
    goto :get_version
)

:get_version
for /F "tokens=2 delims=:, " %%G in ('echo %response% ^| find /I "\"tag_name\":"') do (
    set "version=%%~G"
    goto :fetch_opencore
)

:fetch_opencore
REM Fetch the latest OpenCore version
set "latest_version=%version:"=%"

REM Set the download link
set "LINK=https://github.com/acidanthera/OpenCorePkg/releases/download/%latest_version%/OpenCore-%latest_version%-RELEASE.zip"

REM Define the target directory for extraction
set "target_directory=%~dp0Download"

REM Check if OpenCore has already been downloaded
if exist "%target_directory%\X64" if exist "%target_directory%\Docs" if exist "%target_directory%\Utilities" (
    echo OpenCore is already downloaded.
) else (
    REM Download and unzip OpenCore
    curl -o "%target_directory%\OpenCore-%latest_version%-RELEASE.zip" "%LINK%"
    powershell Expand-Archive -Path "%target_directory%\OpenCore-%latest_version%-RELEASE.zip" -DestinationPath "%target_directory%" -Force
    echo OpenCore downloaded and extracted successfully.
)

REM Create the destination directory
mkdir "%~dp0\system-files"
REM Set the source and destination directories
set "src_folder=%~dp0\system-files"
set "dest_folder=%~dp0\Download\X64\EFI\OC"
REM Copy files with overwrite
xcopy /E /Y "%src_folder%\*" "%dest_folder%"

REM Check if ISK.key exists
if exist "%efikeys_dir%\ISK.key" (
    echo ISK.key was decrypted successfully
)

REM Check if ISK.pem exists
if exist "%efikeys_dir%\ISK.pem" (
    echo ISK.pem was decrypted successfully
)

REM Create the X64-Signed directory
if exist "%target_directory%\X64-Signed" (
    rmdir /S /Q "%target_directory%\X64-Signed"
)
mkdir "%target_directory%\X64-Signed"
set "X64_Signed=%target_directory%\X64-Signed"
REM Set the source and destination directories
set "src_folder=%target_directory%\X64"
set "dest_folder=%target_directory%\X64-Signed"
REM Copy files with overwrite
xcopy /E /Y "%src_folder%\*" "%dest_folder%"

REM Specify the paths to your key and PEM certificate files
set "key=%efikeys_dir%\ISK.key"
set "pem_certificate=%efikeys_dir%\ISK.pem"

REM Sign .kext, .aml, and .efi files in the X64-Signed directory and subdirectories
for /R "%X64_Signed%" %%G in (*.kext *.aml *.efi) do (
    REM Sign the file using signtool.exe and override the original file
    signtool.exe sign /f "%key%" /pem "%pem_certificate%" /fd SHA256 /tr http://timestamp.digicert.com /td sha256 /v "%%G"
)

REM Find the EFI partition
for /F "tokens=2 delims==" %%I in ('wmic partition where "Type='EFI System Partition'" get DeviceID /value ^| findstr /C:"="') do (
    set "efi_partition=%%I"
)

REM Function to install OpenCore without secure boot
:install_without_secure_boot
echo Installing OpenCore without secure boot...
REM Mount the EFI partition
mountvol %efi_partition% /MNT
REM Copy files from X64-Signed folder to the EFI partition
xcopy /E /I /Y "%target_directory%\X64" "\MNT"
REM Unmount the EFI partition
mountvol %efi_partition% /D
goto :end

REM Function to install OpenCore with secure boot
:install_with_secure_boot
echo Installing OpenCore with secure boot...
REM Add .auth files into UEFI firmware
powershell.exe -Command "Install-Module -Name SecureBootUEFI -Force"
powershell.exe -Command "Import-Module SecureBootUEFI"
powershell.exe -Command "Import-SecureBootUEFIKeys -FilePath '%efikeys_dir%\PK.auth' -DatabaseType PK"
powershell.exe -Command "Import-SecureBootUEFIKeys -FilePath '%efikeys_dir%\KEK.auth' -DatabaseType KEK"
powershell.exe -Command "Import-SecureBootUEFIKeys -FilePath '%efikeys_dir%\db.auth' -DatabaseType db"
REM Mount the EFI partition
mountvol %efi_partition% /MNT
REM Copy files from X64-Signed folder to the EFI partition
xcopy /E /I /Y "%target_directory%\X64-Signed" "\MNT"
REM Unmount the EFI partition
mountvol %efi_partition% /D
goto :end

REM Prompt user for installation type
:prompt
echo OpenCore Installation
echo ---------------------
echo Please select the installation type:
echo 1. Install with secure boot
echo 2. Install without secure boot
echo 3. Do not install OpenCore
set /P "choice=Enter your choice (1, 2, or 3): "

REM Validate the user's choice and execute the appropriate function
if %choice% == 1 (
  goto install_with_secure_boot
) else if %choice% == 2 (
  goto install_without_secure_boot
) else if %choice% == 3 (
  echo Skipping OpenCore installation.
) else (
  echo Invalid choice. Please select 1, 2, or 3.
  goto prompt
)

REM Clean up
del "%target_directory%\OpenCore-%latest_version%-RELEASE.zip" 2>nul

:end
endlocal
exit /b
