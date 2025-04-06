@echo off
echo Deploying CloudFormation Stack
echo ============================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0deploy-cloudformation.ps1"
pause
