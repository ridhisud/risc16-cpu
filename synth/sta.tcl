# run with:  openroad -no_init -exit sta.tcl | tee sta_log.txt
read_lef NangateOpenCellLibrary.tech.lef
read_lef NangateOpenCellLibrary.macro.mod.lef
read_liberty NangateOpenCellLibrary_typical.lib
read_verilog netlist.v
link_design cpu_top

# 10 ns clock = 100 MHz. change the period to test other speeds
create_clock -name clk -period 10 [get_ports clk]
set_input_delay  1 -clock clk [all_inputs -no_clocks]
set_output_delay 1 -clock clk [all_outputs]

puts "===== AREA ====="
report_design_area
puts "===== TIMING SUMMARY ====="
report_wns
report_tns
puts "===== CRITICAL PATH ====="
report_checks -path_delay max -fields {slew cap fanout} -digits 3
puts "===== POWER ====="
report_power
