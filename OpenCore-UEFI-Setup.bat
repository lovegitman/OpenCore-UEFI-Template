@echo off

:: Check if running with administrative privileges
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

ping www.google.com -n 1 > nul 2>&1
if errorlevel 1 (
    echo Internet connection not available.
    pause
    exit
)
echo Internet connection is available.

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

REM Function to create certificate and key
:create_cert_key
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

goto :eof

REM Call the function to create certificate and key
call :create_cert_key

if exist "%download_dir%\X64" if exist "%download_dir%\Docs" if exist "%download_dir%\Utilities" (
  echo All three directories (X64, Docs, Utilities) exist.
  REM Add your desired code here when all directories exist
) else (
  echo One or more directories are missing.
  REM Define the GitHub repository
  set repository=acidanthera/OpenCorePkg
  REM Get the latest release information from the GitHub API
  for /f "usebackq tokens=*" %%i in (`curl -s "https://api.github.com/repos/%repository%/releases/latest"`) do set release_info=%%i
  REM Filter out debug assets
  for /f "usebackq tokens=*" %%i in (`echo %release_info% ^| jq -r ".assets ^| map(select(.name | test(\"DEBUG\"; \"i\") ^| not)) ^| .[0].browser_download_url"`) do set download_url=%%i
  REM Extract the file name from the download URL
  for %%i in ("%download_url%") do set file_name=%%~nxi
  REM Define the destination file path
  set destination_path=%download_dir%\%file_name%
  REM Download the latest OpenCore zip file
  curl -L -o "%destination_path%" "%download_url%"
  REM Check if X64 directory is missing
  if not exist "%download_dir%\X64" (
    REM unzip X64 directory from OpenCore
    $archive = Get-Item -Path "%destination_path%"
    $extractPath = Join-Path -Path "%download_dir%" -ChildPath X64
    Expand-Archive -Path $archive.FullName -DestinationPath "%download_dir%" -Force
  )
  REM Check if Docs directory is missing
  if not exist "%download_dir%\Docs" (
    REM unzip Docs directory from OpenCore
    $archive = Get-Item -Path "%destination_path%"
    $extractPath = Join-Path -Path "%download_dir%" -ChildPath Docs
    Expand-Archive -Path $archive.FullName -DestinationPath "%download_dir%" -Force
  )
  REM Check if Utilities directory is missing
  if not exist "%download_dir%\Utilities" (
    REM unzip Utilities directory from OpenCore
    $archive = Get-Item -Path "%destination_path%"
    $extractPath = Join-Path -Path "%download_dir%" -ChildPath Utilities
    Expand-Archive -Path $archive.FullName -DestinationPath "%download_dir%" -Force
  )
  REM Clean up
  del "%destination_path%" 2>nul
)

:: Source folder
set "src_folder=%system_dir%"
:: Destination folder
set "dest_folder=%download_dir%\X64\EFI\OC"
:: Copy files with overwrite
xcopy /E /Y "%src_folder%\*" "%dest_folder%\"

:: Create the X64-Signed directory
if exist "%download_dir%\X64-Signed" (
    rmdir /s /q "%download_dir%\X64-Signed"
)
mkdir "%download_dir%\X64-Signed"
set "X64_Signed=%download_dir%\X64-Signed"

:: Source folder
set "src_folder=%download_dir%\X64"
:: Destination folder
set "dest_folder=%download_dir%\X64-Signed"
:: Copy files with overwrite
xcopy /E /Y "%src_folder%\*" "%dest_folder%\"

REM Sign .efi .kext files in X64-Signed directory and subdirectories
for /r %X64_Signed% %%F in (*.efi, *.kext) do (
    rem Sign the file using osslsigncode and override the original file
    osslsigncode sign -key "%ISK_key%" -cert "%ISK_pem%" -in "%%F" -out "%%F"
)

REM Function to install OpenCore without secure boot
:install_without_secure_boot
REM Find the EFI partition
for /f "usebackq tokens=2 delims==" %%G in (`wmic logicaldisk where "volumename='EFI'" get deviceid /format:value`) do set "efi_partition=%%G"
REM Mount the EFI partition
mountvol %efi_partition% /s
REM Copy files from X64-Signed folder to the EFI partition
xcopy /E /I "%download_dir%\X64" %efi_partition%
REM Set the path to the Opencore bootloader in the EFI partition
set EFI_PATH=\EFI\OC\OpenCore.efi
REM Check if the OpenCore boot entry already exists
bcdedit /enum | findstr /c:"Opencore Bootloader" > nul
IF %errorlevel%==0 (
    echo OpenCore boot entry already exists.
) ELSE (
    echo OpenCore boot entry does not exist. Creating...
    REM Use the bcdedit command to create a new boot entry for OpenCore
    bcdedit /create /d "Opencore Bootloader" /application bootsector
    REM Set the path to the OpenCore EFI file using the detected EFI partition
    bcdedit /set {default} device partition=%efi_partition%
    bcdedit /set {default} path %EFI_PATH%
    REM Set OpenCore as the default boot entry
    bcdedit /default {default}
)
REM Unmount the EFI partition
mountvol %efi_partition% /d
goto :EOF

REM Function to install OpenCore with secure boot
:install_with_secure_boot
REM Add .auth files into UEFI firmware
$PKFile = '%efikeys_dir%\PK.auth'
$KEKFile = '%efikeys_dir%\KEK.auth'
$dbFile = '%efikeys_dir%\db.auth'
$PKImported = Get-SecureBootUEFIFile | Where-Object { $_.FilePath -eq $PKFile }
$KEKImported = Get-SecureBootUEFIFile | Where-Object { $_.FilePath -eq $KEKFile }
$dbImported = Get-SecureBootUEFIFile | Where-Object { $_.FilePath -eq $dbFile }
if (-not $PKImported) {
    Add-SecureBootUEFIFile -FilePath $PKFile
}
if (-not $KEKImported) {
    Add-SecureBootUEFIFile -FilePath $KEKFile
}
if (-not $dbImported) {
    Add-SecureBootUEFIFile -FilePath $dbFile
}
REM Find the EFI partition
for /f "usebackq tokens=2 delims==" %%G in (`wmic logicaldisk where "volumename='EFI'" get deviceid /format:value`) do set "efi_partition=%%G"
REM Mount the EFI partition
mountvol %efi_partition% /s
REM Copy files from X64-Signed folder to the EFI partition
xcopy /E /I "%download_dir%\X64-Signed" %efi_partition%
REM Set the path to the Opencore bootloader in the EFI partition
set EFI_PATH=\EFI\OC\OpenCore.efi
REM Check if the OpenCore boot entry already exists
bcdedit /enum | findstr /c:"Opencore Bootloader" > nul
IF %errorlevel%==0 (
    echo OpenCore boot entry already exists.
) ELSE (
    echo OpenCore boot entry does not exist. Creating...
    REM Use the bcdedit command to create a new boot entry for OpenCore
    bcdedit /create /d "Opencore Bootloader" /application bootsector
    REM Set the path to the OpenCore EFI file using the detected EFI partition
    bcdedit /set {default} device partition=%efi_partition%
    bcdedit /set {default} path %EFI_PATH%
    REM Set OpenCore as the default boot entry
    bcdedit /default {default}
)
REM Unmount the EFI partition
mountvol %efi_partition% /d
goto :EOF

REM Prompt user for installation type
echo "OpenCore Installation"
echo "---------------------"
echo "Please select the installation type:"
echo "1. Install with secure boot"
echo "2. Install without secure boot"
echo "3. Do not install OpenCore"
echo "BEFORE INSTALL MUST MODIFY system-files FOLDER FOR YOUR SYSTEM"
echo "anything inside system-files will be added to Download/X64/EFI/OC/"
set /p "choice=Enter your choice (1, 2, or 3): "

REM Validate the user's choice and execute the appropriate function
if "%choice%"=="1" (
  call :install_with_secure_boot
) else if "%choice%"=="2" (
  call :install_without_secure_boot
) else if "%choice%"=="3" (
  echo "Skipping OpenCore installation."
) else (
  echo "Invalid choice. Please select 1, 2, or 3."
)
