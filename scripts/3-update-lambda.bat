@echo off 
powershell -ExecutionPolicy Bypass -File "%~dp03_update_lambda.ps1" %* 
