@echo off
echo Stopping Python processes...
taskkill /F /IM python.exe
echo.
echo Starting Backend Server...
start python app.py
echo.
echo Backend restarted!
pause
