# Do not need to modify below
set_property PACKAGE_PIN Y9 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10 [get_ports clk]


set_property PACKAGE_PIN  V10 [get_ports scl];  # "JB3"
set_property PACKAGE_PIN  V9 [get_ports scl];  # "JB3"
set_property IOSTANDARD LVCMOS33 [get_ports scl]

set_property PACKAGE_PIN W8  [get_ports sda]
set_property PACKAGE_PIN V8  [get_ports sda]
set_property IOSTANDARD LVCMOS33 [get_ports sda]

set_property PACKAGE_PIN T22 [get_ports led[0]];  # "LD0"
set_property PACKAGE_PIN T21 [get_ports led[1]];  # "LD1"
set_property PACKAGE_PIN U22 [get_ports led[2]];  # "LD2"
set_property PACKAGE_PIN U21 [get_ports led[3]];  # "LD3"
set_property PACKAGE_PIN V22 [get_ports led[4]];  # "LD4"
set_property PACKAGE_PIN W22 [get_ports led[5]];  # "LD5"
set_property PACKAGE_PIN U19 [get_ports led[6]];  # "LD6"
set_property PACKAGE_PIN U14 [get_ports led[7]];  # "LD7"

set_property IOSTANDARD LVCMOS33 [get_ports led]