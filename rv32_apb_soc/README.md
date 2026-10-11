# RV32I single-cycle core + APB subsystem + APB timer (Milestone 1)

Synthesizable SystemVerilog RTL (packages, interface, enums, `always_ff/always_comb`) and a
self-checking, UVM-free testbench. Simulator: **Verilator 5.020** (`--binary --timing --assert`).

## Layout

```
rtl/pkg/rv32_pkg.sv              opcodes, enums, memory map constants
rtl/cpu/                         program_counter, register_file, alu, control_unit,
                                 immediate_generator, instruction_memory, data_memory,
                                 rv32i_single_cycle_core
rtl/bus/apb_if.sv                APB3 interface (master/slave/monitor modports)
rtl/bus/apb_bridge.sv            core request -> APB master FSM
rtl/bus/apb_interconnect.sv      address decode + default (error) slave
rtl/bus/apb_subsystem.sv         bridge + interconnect + timer
rtl/peripherals/apb_timer.sv     APB timer
rtl/top.sv                       core + imem + dmem + apb_subsystem
tb/                              tb_pkg (encoders, check helpers), apb_protocol_checker (SVA),
                                 apb_timer_sb (timer reference model + scoreboard + coverage),
                                 tb_apb (subsystem tests), tb_cpu (ISS scoreboard + directed tests)
sw/asm.py, sample.S, sample.hex  mini assembler, sample program, assembled image
scripts/                         build scripts, RTL file list, mutation check
```

## Architecture

* **Core**: Harvard, single cycle. PC (reset 0) -> 8 KiB instruction memory (comb. read) ->
  `control_unit` / `immediate_generator` / `register_file` (x0 not stored, reads 0, writes
  ignored) -> `alu` -> data access -> write-back. Next PC = PC+4, or PC+imm for taken
  branch / JAL; JAL writes PC+4 to rd.
* **Data address map** (word accesses only): `0x0000_0000-0x0000_0FFF` data RAM (1 cycle);
  `0x4000_xxxx` -> APB bridge; `0x4000_0000-0x4000_0FFF` timer; the rest of `0x4000_xxxx` is
  answered by the interconnect default slave (error). Anything else is a bus fault.
* **Instruction fetch** is a separate space (`0x0000_0000-0x0000_1FFF`). A misaligned or
  out-of-range PC fetches `0x0000_0000`, which is illegal.

### Supported ISA (strict decode)
R: `ADD SUB AND OR XOR SLT`; I: `ADDI ANDI ORI XORI SLTI`; `LW`, `SW`; `BEQ`, `BNE`; `JAL`.
Everything else (incl. wrong funct7/funct3, `SLL*`, `SLTU`, `LUI`, `AUIPC`, `JALR`, `LB/SB`, `BLT..`,
`ECALL`, `FENCE`, all-zero/all-one words) is illegal.

### Fault policy (deterministic)
Faults: illegal instruction (`FAULT_ILLEGAL`), misaligned/unmapped data access or APB `PSLVERR`
(`FAULT_BUS`). The faulting instruction **does not commit** (no register/memory/peripheral
write; PC stays on it), `halted` goes high and `fault_cause` is latched; both are **sticky until
reset**. Nothing executes while halted and no new APB request is issued. Illegal instructions get
all control signals zeroed in the decoder. A load that gets `PSLVERR` does not write `rd`.

### APB timing decisions
* APB3 signals `PCLK PRESETn PADDR PSEL PENABLE PWRITE PWDATA PRDATA PREADY PSLVERR`; reset is
  asynchronous-assert, active low, shared with the core.
* Bridge FSM `IDLE -> SETUP -> ACCESS(+waits) -> IDLE`. The request is captured in IDLE (cycle 1),
  SETUP is cycle 2, ACCESS is cycle 3 and repeats until `PREADY`. **Minimum 3 cycles per access,
  `3 + wait` with wait states. Slaves may wait**: the timer has parameter `WAIT_STATES`
  (default 0, tested with 0/2/3). Responses are never faked: `resp_done` is only asserted in an
  ACCESS cycle with `PREADY=1`.
* **CPU integration = stall**: while an APB request is pending (`req_valid && !resp_done`) the
  core holds PC and commits nothing (no register write, no dmem write). The request is a level
  derived from the (stable) instruction; the bridge accepts it once in IDLE and ignores it
  until it completes, so side effects occur exactly once (timer registers change only on the
  `PSEL&PENABLE&PREADY` cycle). The instruction commits in the cycle `resp_done=1`.
* Interconnect: timer window `PADDR[31:12]==0x40000`; other addresses -> default slave: zero
  wait, `PSLVERR=1`, `PRDATA=0`. Timer invalid offset (`>=0x10`) or `PADDR[1:0]!=0`:
  `PSLVERR=1`, `PRDATA=0`, no side effect. `PSLVERR` is only driven in the completing cycle.

### Timer registers (base `0x4000_0000`)
| Off | Name    | Description |
|-----|---------|-------------|
| 0x0 | CONTROL | bit0 enable, bit1 auto-reload (31:2 read 0, writes ignored) |
| 0x4 | COUNTER | current count, R/W (a write replaces the count) |
| 0x8 | RELOAD  | reload value, R/W (only used on auto-reload expiry) |
| 0xC | STATUS  | bit0 expired, write-1-to-clear |

All reset to 0 (async). Per clock edge: if `enable && COUNTER!=0` (and no COUNTER write this edge)
COUNTER decrements; when it goes `1 -> 0` the timer **expires**: `STATUS.expired<=1`, then
auto-reload=1: `COUNTER<=RELOAD` (enable stays), else `enable<=0`. A counter loaded with N
expires N clock edges after the enable edge. `RELOAD=0`+auto-reload: counter reloads to 0, stays
enabled and idle (single expiry). `RELOAD=1`+auto-reload: expires every clock. Enabled with
`COUNTER=0`: nothing happens. APB writes override the timer's own update of the same register,
except an expiry coinciding with a STATUS W1C keeps `expired=1` (no lost event).

## Verification

* `tb_apb` (run for `WAIT_STATES=0` and `3`): reset values, latency (`3+wait`), R/W of all
  registers incl. reserved bits, exact per-clock decrement, one-shot, auto-reload,
  `RELOAD=0/1`, pause/resume, counter write while running, W1C corner cases, 10 unmapped /
  invalid addresses (read+write, latency, no side effects), reset (also mid-transfer), 4000
  random transfers checked against the reference model every cycle.
* `tb_cpu` (run for `WAIT_STATES=0` and `3`, plus a sample-program run through the
  `IMEM_INIT` parameter): reset/x0, ALU incl. signed/overflow/immediate sign extension, loops,
  LW/SW, branches (taken/not-taken, negative offsets, offsets with bits 11/12 set), JAL
  link/targets, 34 illegal encodings + bad fetch addresses, 9 data/bus fault cases, timer
  through the CPU (R/W, auto-reload poll, one-shot, back-to-back), reset mid-APB-transfer.
* **Scoreboard**: an independent ISS compares PC and all 32 registers after every cycle,
  checks every store, and consumes APB results from the timer reference model. Each
  APB completion must correspond to exactly one retiring/faulting APB instruction (no stray or
  duplicate transfers); timer write side effects are counted against valid APB stores; max
  stall length must equal `2+WAIT_STATES`.
* **Assertions (SVA)**: APB phases (PENABLE needs PSEL, SETUP->ACCESS, stability across SETUP and
  waits, PENABLE low after completion, PSLVERR only on completion, no X), reset, x0 read, halt
  stickiness/no activity, no commit and PC stable during APB wait, legal APB requests.
* **Coverage**: Verilator 5.020 has no `covergroup` support, so coverage is **manual bins**
  (instruction classes + fault classes, branch outcomes, load/store x dmem/APB, APB read/write x
  register offset, APB errors, timer one-shot/auto-reload/`RELOAD=0/1` expiry, W1C clear,
  negative immediate, x0 destination, APB stall). Missing bins are printed and fail the test.
  This is bin-hit coverage, not a tool-generated coverage database.
* Not UVM; module-based portable testbench (no classes needed).

## Commands (run from this directory)

```
make lint          # verilator --lint-only -Wall on the RTL
make hex           # assemble sw/sample.S -> sw/sample.hex (python3 sw/asm.py)
make apb           # tb_apb, WAITS="0 3"
make cpu           # tb_cpu, WAITS="0 3"
make sample        # sample.hex via IMEM_INIT parameter ($readmemh inside the RTL imem)
make regress       # all of the above; prints "REGRESSION: ALL PASS"
make mutation      # optional: injects 13 RTL bugs, confirms the testbench fails on each
```
Each simulation prints `... : PASS/FAIL` and calls `$fatal` (non-zero exit) on any failed check.

Instruction memory init: `instruction_memory #(.INIT_FILE("sw/sample.hex"))` via
`top #(.IMEM_INIT("sw/sample.hex"))` (`$readmemh`, one hex word per line); `tb_cpu` otherwise
backdoor-loads its generated programs.

## Limitations / not done

* Milestone 1 scope only: no pipeline, SPI, GPIO, cache, interrupts, other instructions.
* Only Verilator was exercised; Icarus 12 was installed but not used (interfaces/SVA there are
  incomplete). No commercial simulator, no formal tool, **no synthesis was run**, so
  synthesizability is by construction/lint only. The `initial` memory-clearing blocks in the
  RAM models are simulation/FPGA-style initialisation.
* Hierarchical interface references as module ports crash Verilator 5.020 when parameters are
  overridden, so the testbench checker/scoreboard take plain signals.
* Data RAM and instruction ROM are separate address spaces (Harvard), both at address 0.
* No byte/halfword access, no misaligned support (fault instead).
