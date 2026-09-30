@echo off
echo Preparing project assets...
"%~dp0tools\godot\Godot.exe" --headless --editor --path "%~dp0." --import --log-file "%~dp0research\import_water_lab.log"
if errorlevel 1 (
  echo Asset import failed. See research\import_water_lab.log for details.
  pause
  exit /b 1
)
"%~dp0tools\godot\Godot.exe" --path "%~dp0." res://scenes/water_lab.tscn --log-file "%~dp0research\water_lab.log" %*
