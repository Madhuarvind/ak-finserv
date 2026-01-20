@echo off
echo Stopping running Python processes...
taskkill /F /IM python.exe
echo.
echo Installing dependencies...
pip install -r requirements.txt
echo.
echo Restarting backend server...
start python app.py
echo.
echo Done! You can close this window.
pause
