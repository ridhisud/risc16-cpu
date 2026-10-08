#!/bin/sh
# usage: cd sim && sh run.sh      (needs iverilog; open cpu.vcd with GTKWave)
cp ../rtl/program.hex .
iverilog -g2012 -o simv ../rtl/*.v ../tb/cpu_checker.v ../tb/tb_cpu.v || exit 1
vvp simv
cat coverage_report.txt
