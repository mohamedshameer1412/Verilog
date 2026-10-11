#!/bin/sh
# usage: build_cpu.sh <wait_states> [imem_init_hex]
set -e; cd "$(dirname "$0")/.."
if [ -n "$2" ]; then tag=w$1_init; extra="-GIMEM_INIT=\"$2\""; else tag=w$1; extra=""; fi
verilator --binary --timing --assert -sv -Wno-fatal -Wno-WIDTH -Wno-UNUSED -Wno-DECLFILENAME -Wno-INITIALDLY -Wno-TIMESCALEMOD \
  --top-module tb_cpu -GWAIT_STATES=$1 $extra -Mdir build/cpu_$tag -f scripts/rtl_files.f \
  tb/tb_pkg.sv tb/apb_protocol_checker.sv tb/apb_timer_sb.sv tb/tb_cpu.sv >build/cpu_$tag.log 2>&1 || { grep -v '^make\|^g++' build/cpu_$tag.log | head -40; exit 1; }
