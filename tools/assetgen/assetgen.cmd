@echo off
rem Wrapper: run the pipeline from any directory.
rem   assetgen.cmd gui  --config work\mara\config.json
rem   assetgen.cmd run  --config work\mara\config.json --all
setlocal
set "ROOT=%~dp0"
set "PATH=%SystemRoot%\System32;%SystemRoot%;%PATH%"
set "PYTHONPATH=%ROOT%"
chcp 65001 >nul
python -m assetgen.cli %*
