@echo off
echo ==================================================
echo Update Alexa Skill Account Linking
echo ==================================================
echo.
echo This script will:
echo 1. Get your Cognito app client details
echo 2. Automatically update your Alexa skill configuration
echo 3. Configure account linking with the latest settings
echo.
echo IMPORTANT: This requires ASK CLI to be installed and configured.
echo If you don't have ASK CLI, you'll need to update manually.
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0update-alexa-skill.ps1"

echo.
echo If successful, your Alexa skill has been updated.
echo Now test the account linking in the Alexa app again.
echo.
pause