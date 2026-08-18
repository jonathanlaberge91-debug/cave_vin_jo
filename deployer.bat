@echo off
REM Deploie l'app cave a vin sur https://cave-vin-jo.web.app
cd /d "%~dp0"
"C:\Program Files\Git\bin\bash.exe" tool/deploy.sh
pause
