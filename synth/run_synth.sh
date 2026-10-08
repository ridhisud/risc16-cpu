#!/bin/sh
# usage: cd synth && sh run_synth.sh
cp ../rtl/program.hex .
[ -f NangateOpenCellLibrary_typical.lib ] || wget -q https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/master/flow/platforms/nangate45/lib/NangateOpenCellLibrary_typical.lib
yosys -q -l yosys.log -s synth_nangate.ys
tail -5 area_report.txt
openroad -no_init -exit sta.tcl | tee sta_log.txt
