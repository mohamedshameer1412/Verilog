# Requires: verilator >= 5.020 (with --binary/--timing), python3 (assembler only)
SHELL := /bin/sh
WAITS ?= 0 3

.PHONY: all lint hex apb cpu sample regress clean mutation
all: regress

lint:
	verilator --lint-only -Wall -sv --top-module top -f scripts/rtl_files.f

hex: sw/sample.hex
sw/sample.hex: sw/sample.S sw/asm.py
	python3 sw/asm.py sw/sample.S sw/sample.hex

apb:
	@set -e; for w in $(WAITS); do scripts/build_apb.sh $$w; ./build/apb_w$$w/Vtb_apb | grep -E "FAIL|checks=|TB_APB"; done

cpu:
	@set -e; for w in $(WAITS); do scripts/build_cpu.sh $$w; ./build/cpu_w$$w/Vtb_cpu | grep -E "FAIL|checks=|TB_CPU"; done

# sample program loaded through the IMEM_INIT elaboration parameter ($readmemh in RTL)
sample: hex
	scripts/build_cpu.sh 0 sw/sample.hex
	./build/cpu_w0_init/Vtb_cpu | grep -E "FAIL|checks=|TB_CPU"

regress: lint hex apb cpu sample
	@echo "REGRESSION: ALL PASS"

mutation:
	python3 scripts/mutation_check.py

clean:
	rm -rf build
