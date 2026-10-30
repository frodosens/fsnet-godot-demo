@echo off
rem Open the wizard.
rem   gui.cmd                  -> work\default\config.json
rem   gui.cmd mara             -> work\mara\config.json
rem   gui.cmd D:\path\c.json  -> that file
rem   gui.cmd mara --echo      -> print the resolved config path only
setlocal
set "ROOT=%~dp0"
set "PATH=%SystemRoot%\System32;%SystemRoot%;%PATH%"
set "PYTHONPATH=%ROOT%"
chcp 65001 >nul

set "ARG=%~1"
if /i "%~1"=="--echo" (
  echo config: %ROOT%work\default\config.json
  goto :eof
)
set "ECHO_ONLY="
if /i "%~2"=="--echo" set "ECHO_ONLY=1"

if "%ARG%"=="" (
  set "CFG=%ROOT%work\default\config.json"
  set "ID=default"
) else (
  if /i "%~x1"==".json" (
    set "CFG=%~1"
    set "ID="
  ) else (
    set "CFG=%ROOT%work\%ARG%\config.json"
    set "ID=%ARG%"
  )
)

echo config: %CFG%
if defined ECHO_ONLY goto :eof

set "NEED_NEW="
if not exist "%CFG%" set "NEED_NEW=1"
if exist "%CFG%" for %%A in ("%CFG%") do if %%~zA LSS 2 set "NEED_NEW=1"

if defined NEED_NEW (
  if defined ID (
    python -m assetgen.cli new --id "%ID%" --desc "pixel character, edit this description" --out "%CFG%"
  ) else (
    python -m assetgen.cli new --id default --desc "pixel character, edit this description" --out "%CFG%"
  )
  if errorlevel 1 goto :error
)
python -m assetgen.cli gui --config "%CFG%"
goto :eof
:error
echo failed to create config
exit /b 1
