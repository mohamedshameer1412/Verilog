# UNIT I – Topic 1: VLSI Technology Overview

## 1. VLSI Technology Overview
- **VLSI** = Very Large Scale Integration (millions of transistors on a chip)
- Technology nodes: 180nm ? 130nm ? 90nm ? 65nm ? 45nm ? 28nm ? 7nm ? 3nm
- More transistors = faster, smaller, lower power (Moore's Law)

## 2. IP, Subsystems, and Chips
- **IP (Intellectual Property)**: Pre-designed, reusable hardware blocks
  - Soft IP  ? RTL code (portable, flexible)
  - Hard IP  ? Fixed layout (e.g., SRAM, PLL)
  - Firm IP  ? Netlist (between soft and hard)
- **Subsystems**: Groups of IPs (e.g., USB subsystem, Memory subsystem)
- **SoC (System on Chip)**: A full system (CPU + GPU + Memory + I/O) on one chip

## 3. SOC Architecture
```
+--------------------------------------------+
|  SoC                                       |
|  +--------+   +--------+   +----------+   |
|  |  CPU   |   |  GPU   |   |  Memory  |   |
|  +--------+   +--------+   +----------+   |
|  +--------+   +--------+   +----------+   |
|  |  USB   |   | PCIE   |   |   I2C    |   |
|  +--------+   +--------+   +----------+   |
|            [Interconnect Bus]              |
+--------------------------------------------+
```

## 4. VLSI Design Flow (RTL to GDSII)
```
Specification
    ?
RTL Coding (SystemVerilog / Verilog / VHDL)
    ?
Functional Simulation (verify logic)
    ?
Synthesis (RTL ? Gate Netlist)
    ?
Static Timing Analysis (STA)
    ?
Place & Route (PnR)
    ?
Physical Verification (DRC, LVS)
    ?
GDSII (chip layout sent to foundry)
```

## 5. VLSI Design Verification Flow
```
Testbench (SystemVerilog)
    ?
Simulation (ModelSim, VCS, Xcelium)
    ?
Functional Coverage
    ?
Formal Verification
    ?
Emulation / Prototyping (FPGA)
    ?
Silicon Bring-up (post-tapeout)
```

## Key Tools
| Stage          | Tool Examples               |
|----------------|-----------------------------|
| Simulation     | ModelSim, VCS, Xcelium      |
| Synthesis      | Design Compiler, Genus      |
| PnR            | Innovus, ICC2               |
| STA            | PrimeTime                   |
| Verification   | JasperGold, VC Formal       |

## Summary
- VLSI flows from specification ? RTL ? synthesis ? layout ? chip
- SystemVerilog is the industry standard for both design AND verification
- Next: Start writing your first SystemVerilog code!
