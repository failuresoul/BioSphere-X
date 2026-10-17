@echo off
title BioSphere-X Launcher
echo ========================================================
echo   Launching BioSphere-X with Python AI Backend
echo ========================================================
cd /d "%~dp0"

echo [1/2] Initializing Python AI Backend Server...
start "BioSphere-X AI Backend" cmd /c "%~dp0start_ai_backend.bat"

echo Waiting for backend socket to initialize...
timeout /t 2 /nobreak >nul

echo [2/2] Launching BioSphere-X Godot Client...
start "" "C:\Users\USER\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0"
