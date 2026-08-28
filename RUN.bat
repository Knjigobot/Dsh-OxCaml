@echo off
title Dsh-OxCaml CLI
cd /d "%~dp0"
echo ========================================================================
echo   DSH-OXCAML: DeepSeek Agent Harness in OxCaml on Cordis
echo ========================================================================
where dune >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    dune exec bin/main.exe -- %*
) else (
    echo [ERROR] Dune not found in PATH.
    pause
)
