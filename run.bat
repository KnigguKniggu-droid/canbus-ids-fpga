@echo off
cd /d "%~dp0"
iverilog -o can_ids_sim.vvp rtl\can_ids.v tb\can_ids_tb.v
if errorlevel 1 ( echo Build failed. Is Icarus Verilog installed and on PATH? & pause & exit /b 1 )
vvp can_ids_sim.vvp
echo.
echo (waveform written to can_ids.vcd - open with: gtkwave can_ids.vcd)
pause
