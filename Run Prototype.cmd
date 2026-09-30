@echo off
echo Preparing project assets...
"%~dp0tools\godot\Godot.exe" --headless --editor --path "%~dp0." --import --log-file "%~dp0research\import.log"
if errorlevel 1 (
  echo Asset import failed. See research\import.log for details.
  pause
  exit /b 1
)
"%~dp0tools\godot\Godot.exe" --path "%~dp0." --log-file "%~dp0research\play.log" %*
