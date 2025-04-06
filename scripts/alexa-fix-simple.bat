@echo off
echo ==================================================
echo Simple Alexa Configuration Fix
echo ==================================================
echo.
echo This script will:
echo 1. Update your app client with Alexa-compatible settings
echo 2. Display all configuration values needed for your Alexa skill
echo 3. Save the values to a file for reference
echo.
echo IMPORTANT: You'll need to copy these values to your
echo Alexa developer console account linking settings.
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0alexa-fix-simple.ps1"

echo.
echo After running this script, see alexa_config.txt for
echo the values to enter in the Alexa developer console.
echo.
echo Please follow the instructions in ALEXA_ACCOUNT_LINKING.md
echo to complete the configuration.
echo.
pause