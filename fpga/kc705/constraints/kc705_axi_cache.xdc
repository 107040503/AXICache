set_property CONFIG_VOLTAGE 2.5 [current_design]
set_property CFGBVS VCCO [current_design]

# KC705 200 MHz differential system clock.
set_property PACKAGE_PIN AD12 [get_ports clk_p]
set_property PACKAGE_PIN AD11 [get_ports clk_n]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {clk_p clk_n}]
set_property DIFF_TERM TRUE [get_ports {clk_p clk_n}]
create_clock -name sys_clk_200mhz -period 5.000 [get_ports clk_p]

# CPU_RESET push button, active high.
set_property PACKAGE_PIN AB7 [get_ports reset]
set_property IOSTANDARD LVCMOS15 [get_ports reset]
set_false_path -from [get_ports reset]

# User LEDs 0..3, VCCO 1.5 V bank.
set_property PACKAGE_PIN AB8 [get_ports {leds[0]}]
set_property PACKAGE_PIN AA8 [get_ports {leds[1]}]
set_property PACKAGE_PIN AC9 [get_ports {leds[2]}]
set_property PACKAGE_PIN AB9 [get_ports {leds[3]}]
set_property IOSTANDARD LVCMOS15 [get_ports {leds[0] leds[1] leds[2] leds[3]}]

# User LEDs 4..7, VCCO 2.5 V banks.
set_property PACKAGE_PIN AE26 [get_ports {leds[4]}]
set_property PACKAGE_PIN G19  [get_ports {leds[5]}]
set_property PACKAGE_PIN E18  [get_ports {leds[6]}]
set_property PACKAGE_PIN F16  [get_ports {leds[7]}]
set_property IOSTANDARD LVCMOS25 [get_ports {leds[4] leds[5] leds[6] leds[7]}]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

