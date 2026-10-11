#!/bin/sh
# usage: build_apb.sh <wait_states>
set -e; cd "$(dirname "$0")/.."
verilator --binary --timing --assert -sv -Wno-fatal -Wno-WIDTH -Wno-UNUSED -Wno-DECLFILENAME -Wno-INITIALDLY -Wno-TIMESCALEMOD \
  --top-module tb_apb -GWAIT_STATES=$1 -Mdir build/apb_w$1 -f scripts/rtl_files.f \
  tb/tb_pkg.sv tb/apb_protocol_checker.sv tb/apb_timer_sb.sv tb/tb_apb.sv >build/apb_w$1.log 2>&1 || { tail -30 build/apb_w$1.log; exit 1; }
