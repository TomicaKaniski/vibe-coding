@echo off
REM -----------------------------
REM run_outlook_ai.bat
REM Batch script to run the Outlook AI Python assistant
REM -----------------------------

REM Change directory to the folder where this batch file resides
cd /d "%~dp0"

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Run the main Python script
python main.py
set EXIT_CODE=%ERRORLEVEL%

REM Deactivate virtual environment
call venv\Scripts\deactivate.bat

REM Pause for review
echo.
echo Script finished with exit code %EXIT_CODE%.
pause
exit /b %EXIT_CODE%
