@echo off
title J.A.R.V.I.S.
cd /d "%~dp0"

rem Private keys, kept out of git. Edit jarvis-secrets.cmd to add them.
if exist "%~dp0jarvis-secrets.cmd" call "%~dp0jarvis-secrets.cmd"

rem The ElevenLabs voice JARVIS speaks with. Needs a key in jarvis-secrets.cmd;
rem without one he falls back to the browser voice and this is ignored.
rem A default, not an assignment: jarvis-secrets.cmd is read just above, so a
rem voice ID set there is the one that wins. Setting it unconditionally here
rem overwrote the users choice every time, silently.
if not defined JARVIS_VOICE_ID set "JARVIS_VOICE_ID=IRHApOXLvnW57QJPQH2P"

rem JARVIS needs a real Chrome or Edge window for the microphone.
set "BROWSER="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "BROWSER=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not defined BROWSER if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "BROWSER=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not defined BROWSER if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "BROWSER=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if not defined BROWSER if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" set "BROWSER=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not defined BROWSER set "BROWSER=explorer.exe"

echo.
echo  Starting J.A.R.V.I.S. with WRITES ENABLED (it can run commands, edit files, send things).
echo  The interface opens in your browser in a few seconds: click INITIALISE, then say "Hey Jarvis".
echo  Close this window or press Ctrl+C to stop.
echo.

rem Open the interface once the dev server has had a moment to come up.
start "" /min cmd /c "timeout /t 10 /nobreak >nul & start "" "%BROWSER%" http://localhost:5173"

call npm start -- --writes
pause
