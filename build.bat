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
    echo [*] Dune toolchain not in PATH.
    echo [*] Install via: opam install dune ocaml
)
pause
