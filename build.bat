@REM **************************************************************************
@REM compiling an x64 windows executable.
@REM **************************************************************************
@echo off
setlocal EnableDelayedExpansion

@REM **************************************************************************
@REM config
@REM

set ROOT=%CD%

set IN=%ROOT%
set OUT=%ROOT%\bin

set EXE_NAME=gpaint

if not exist %OUT% ( mkdir %OUT% )

@REM **************************************************************************
@REM run
@REM

if "%~1"=="run" (
    %OUT%\%EXE_NAME%.exe
    @REM remedybg.exe -g -q %OUT%\%EXE_NAME%.exe
    goto :EOF
)

@REM **************************************************************************
@REM compile
@REM

set CFLAGS=-debug -target:windows_amd64 -subsystem:console
REM -sanitize:address
REM -o:speed -o:aggressive
REM

set COMPILE_CMD=odin.exe build %IN% %CFLAGS% -out:%EXE_NAME%.exe -build-mode:exe
pushd %OUT%
    echo %COMPILE_CMD%
    %COMPILE_CMD%
popd

@REM **************************************************************************
:EOF
endlocal
exit /B %ERRORLEVEL%
