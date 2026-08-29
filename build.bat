@echo off
title Dsh-OxCaml Build & Test
cd /d "%~dp0"
echo ======================================================
echo  DSH-OXCAML: DEEPSEEK AGENT HARNESS (OXCAML PORT)
echo ======================================================
where dune >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [*] Building Dsh-OxCaml libraries and binaries...
    dune build @all
    echo [*] Running Dsh-OxCaml test suite...
    dune runtest
) else (
    echo [!] Dune toolchain is not currently in PATH.
    echo.
    echo [*] To install Dune ^& OCaml on Windows:
    echo     Option 1 (Winget): winget install ocaml.opam
    echo     Option 2 (DKML):   https://diskuv.com/dkml/installer/
    echo     Option 3 (WSL):    wsl -- sudo apt install ocaml dune
    echo.
    echo [*] You can also launch the Dsh-OxCaml Web Studio directly via RUN.bat!
    echo.
)
pause
