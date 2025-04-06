@echo off
echo ==================================================
echo Create New App Client for Alexa
echo ==================================================
echo.
echo This script will:
echo 1. Create a completely new app client specifically for Alexa
echo 2. Configure it with the exact settings needed
echo 3. Generate new client ID and secret
echo 4. Save the configuration for Alexa skill update
echo.
echo This is the most reliable approach when experiencing
echo persistent account linking issues.
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0create-new-app-client.ps1"

echo.
echo After running this script:
echo 1. Go to the Alexa developer console
echo 2. Update your skill's account linking settings
echo 3. Use the new client ID and secret from new_alexa_config.txt
echo 4. Save the changes and test again
echo.
pause