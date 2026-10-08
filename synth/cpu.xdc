# 100 MHz target - tighten (e.g. 6.0) after the first timing report to find fmax
create_clock -period 10.000 -name clk [get_ports clk]
