@echo off
REM This batch file ensures PowerShell scripts can run without execution policy issues

echo Checking if PowerShell scripts need to be fixed...

REM Check if scripts can be executed
powershell -Command "& {try { Get-ExecutionPolicy -Scope CurrentUser | Out-Null; exit 0 } catch { exit 1 }}"
if %ERRORLEVEL% NEQ 0 (
    echo Setting PowerShell execution policy to RemoteSigned for the current user
    powershell -Command "& {Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force}"
) else (
    echo PowerShell execution policy already configured
)

echo Creating batch file launchers for PowerShell scripts...

REM Create batch files to launch the PowerShell scripts
echo @echo off > 1-init-resources.bat
echo powershell -ExecutionPolicy Bypass -File "%%~dp01_init_resources.ps1" %%* >> 1-init-resources.bat

echo @echo off > 2-deploy-skill.bat
echo powershell -ExecutionPolicy Bypass -File "%%~dp02_deploy_skill.ps1" %%* >> 2-deploy-skill.bat

echo @echo off > 3-update-lambda.bat
echo powershell -ExecutionPolicy Bypass -File "%%~dp03_update_lambda.ps1" %%* >> 3-update-lambda.bat

echo @echo off > check-status.bat
echo powershell -ExecutionPolicy Bypass -File "%%~dp0check_status.ps1" %%* >> check-status.bat

echo @echo off > test-lambda.bat
echo powershell -ExecutionPolicy Bypass -File "%%~dp0test_lambda.ps1" %%* >> test-lambda.bat

echo Done! You can now run the following batch files:
echo   1-init-resources.bat
echo   2-deploy-skill.bat
echo   3-update-lambda.bat
echo   check-status.bat
echo   test-lambda.bat

echo.
echo Press any key to exit...
pause > nul