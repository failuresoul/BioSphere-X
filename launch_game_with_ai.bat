@echo off
title BioSphere X Launcher
echo ========================================================
echo   Launching BioSphere X with Python AI Backend
echo ========================================================
cd /d "%~dp0"

echo [1/2] Initializing Python AI Backend Server...
curl.exe --fail --silent http://127.0.0.1:8000/health >nul 2>&1
if errorlevel 1 (
    start "BioSphere X AI Backend" cmd /c "%~dp0start_ai_backend.bat"
    echo Waiting for backend socket to initialize...
    powershell -NoProfile -Command "Start-Sleep -Seconds 2" >nul
)

echo [2/2] Launching BioSphere X Godot Client...
set "GODOT_EXE="
for /f "delims=" %%F in ('where godot.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%F"
if not defined GODOT_EXE (
    for /f "delims=" %%F in ('where /r "%LOCALAPPDATA%\Microsoft\WinGet\Packages" Godot_v*-stable_win64.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%F"
)
if not defined GODOT_EXE (
    echo Godot 4 was not found. Install it with: winget install --id GodotEngine.GodotEngine --exact
    pause
    exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0."
