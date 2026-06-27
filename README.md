# CAN Bus IDS — Hardware (Verilog / FPGA)

> **TL;DR** — The CAN intrusion detector in **synthesizable Verilog**, built for an FPGA
> gateway. A self-checking testbench passes under Icarus Verilog: no false alarms on normal
> traffic, then it raises TIMING + UNKNOWN_ID alerts on attacks at **1-cycle latency**.

### Quickstart
```bash
iverilog -o can_ids_sim.vvp rtl/can_ids.v tb/can_ids_tb.v && vvp can_ids_sim.vvp
# (Windows: double-click run.bat)
```

A **timing-based CAN intrusion detector implemented in synthesizable Verilog** — the
hardware version of the Python CAN IDS, meant to sit on an **embedded automotive gateway**
(an FPGA between the CAN transceiver and the ECUs) and flag attacks at line rate, in one
clock cycle.

The **hardware layer** of the autonomous-vehicle security portfolio. Core ECE: digital
design / RTL, finite-state logic, fixed-point timing — implemented and verified with a
self-checking testbench in **Icarus Verilog**.

## What it detects (1-cycle latency)
| Alert | Condition |
|---|---|
| `UNKNOWN_ID` | an arbitration ID not in the configured baseline table (flooding / injection) |
| `TIMING` | a known ID arriving faster than its minimum inter-arrival period (spoof / injection) |

A free-running cycle counter timestamps each frame; per-ID registers hold the last-seen
timestamp and the minimum allowed period (the "learned" baseline, loaded at reset — on a
real gateway, firmware writes it after a clean window).

## Simulation result
```
-- after normal traffic: timing=0 unknown=0   (no false alarms)
[..] TIMING alert  id=0x0c0                     (injection: 0x0C0 arrived too fast)
[..] UNKNOWN alert id=0x000  (x3)               (DoS flood with unseen ID 0x000)
RESULT: PASS
```

## Run it
Needs **Icarus Verilog** (`winget install Icarus.Verilog`, or apt/brew `iverilog`):
```bash
iverilog -o can_ids_sim.vvp rtl/can_ids.v tb/can_ids_tb.v
vvp can_ids_sim.vvp
# (Windows: just run  run.bat)
```
View the waveform with GTKWave: `gtkwave can_ids.vcd`.

## Files
```
canbus-ids-fpga/
├─ rtl/can_ids.v       # synthesizable IDS module (the deployable hardware)
├─ tb/can_ids_tb.v     # self-checking testbench (normal + 2 attacks)
└─ run.bat             # compile + simulate
```

## FPGA deployment path (real hardware)
The RTL is synthesizable as-is. To run it on a real board:
1. Wire a CAN transceiver (e.g. MCP2551/SN65HVD230) to the FPGA; recover `frame_valid` +
   `arb_id` from the CAN RX line (add a small CAN-frame deserializer).
2. Synthesize `can_ids.v` for a cheap FPGA — **iCEBreaker / TinyFPGA (~$30-70)** with the
   open-source **Yosys + nextpnr** toolchain, or a **Basys-3 (Xilinx)** with Vivado.
3. Route `timing_alert` / `unknown_alert` to an LED or back onto the bus.

## Honest scope
- This is the **detection core** — a CAN-frame deserializer (bitstream → arb_id + strobe) is
  the next RTL block for a full end-to-end gateway; the testbench supplies frames directly.
- The baseline table is loaded at reset (parameterized); a learning/calibration FSM is the
  natural extension. Same detection logic as the validated Python IDS, now in hardware.
