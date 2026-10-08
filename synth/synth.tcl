# Vivado batch:  vivado -mode batch -source synth.tcl
# Part is just an example - change to your board's part.
set part xc7a35tcpg236-1
read_verilog [glob ../rtl/*.v]
read_xdc cpu.xdc
synth_design -top cpu_top -part $part
report_utilization    -file area_report.txt
report_timing_summary -file timing_report.txt
report_timing -sort_by group -max_paths 5 -path_type full -file critical_path.txt
report_power          -file power_report.txt
