#!/usr/bin/env python3
"""Sanity check of the testbench: inject one RTL bug at a time into a scratch copy and
confirm the testbench FAILS. Not part of the normal regression (slow)."""
import os, shutil, subprocess, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
M = [
 ("alu SLT unsigned",        "rtl/cpu/alu.sv", "$signed(a) < $signed(b)", "a < b", 0),
 ("BNE decoded as BEQ",      "rtl/cpu/control_unit.sv", "3'b001:  branch_ne = 1'b1;", "3'b001:  branch_eq = 1'b1;", 0),
 ("B-imm bit order",         "rtl/cpu/immediate_generator.sv", "instr[31], instr[7], instr[30:25]", "instr[7], instr[31], instr[30:25]", 0),
 ("I-imm not sign-extended", "rtl/cpu/immediate_generator.sv", "IMM_I:   imm = {{20{instr[31]}}", "IMM_I:   imm = {20'b0", 0),
 ("JAL target from pc+4",    "rtl/cpu/rv32i_single_cycle_core.sv", "assign pc_target = pc + imm;", "assign pc_target = pc_plus4 + imm;", 0),
 ("commit during APB stall", "rtl/cpu/rv32i_single_cycle_core.sv", "!fault_event && !apb_stall;", "!fault_event;", 3),
 ("fake PREADY (no wait)",   "rtl/peripherals/apb_timer.sv", "access && (wait_q == 8'd0)", "access", 3),
 ("timer write w/o PREADY",  "rtl/peripherals/apb_timer.sv", "assign wr_complete = complete &&", "assign wr_complete = access &&", 3),
 ("W1C loses expiry",        "rtl/peripherals/apb_timer.sv", "PWDATA[0] && !expiring", "PWDATA[0]", 0),
 ("bridge skips SETUP",      "rtl/bus/apb_bridge.sv", "state   <= S_SETUP;", "state   <= S_ACCESS;", 0),
 ("unmapped returns OK",     "rtl/bus/apb_interconnect.sv", "(sel_dflt && up.PENABLE);\nendmodule", "1'b0;\nendmodule", 0),
 ("illegal not halting",     "rtl/cpu/rv32i_single_cycle_core.sv", "(illegal || mem_fault ||", "(mem_fault ||", 0),
 ("timer expiry off by one", "rtl/peripherals/apb_timer.sv", "(counter_q == 32'd1);", "(counter_q == 32'd2);", 0),
]
bad = 0
for name, f, old, new, w in M:
    d = os.path.join(root, "build", "mut"); shutil.rmtree(d, ignore_errors=True); os.makedirs(d)
    for sub in ("rtl", "tb", "scripts", "sw"): shutil.copytree(os.path.join(root, sub), os.path.join(d, sub))
    os.makedirs(os.path.join(d, "build"))
    p = os.path.join(d, f); s = open(p).read()
    if old not in s: print("PATTERN NOT FOUND", name); bad += 1; continue
    open(p, "w").write(s.replace(old, new, 1))
    r = subprocess.run(["sh", "scripts/build_cpu.sh", str(w)], cwd=d, capture_output=True, text=True)
    if r.returncode: print(f"{name}: BUILD ERROR\n{r.stdout[-500:]}"); bad += 1; continue
    r = subprocess.run([f"build/cpu_w{w}/Vtb_cpu"], cwd=d, capture_output=True, text=True)
    caught = r.returncode != 0 or "FAIL" in r.stdout
    print(f"{'CAUGHT ' if caught else 'MISSED '} {name} (WAIT_STATES={w})"); sys.stdout.flush()
    bad += (not caught)
sys.exit(1 if bad else 0)
