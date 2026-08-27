# Generic pre-synthesis ASIC target. Library-specific uncertainty and IO delays must be added.
create_clock -name Clk -period 2.000 [get_ports Clk]
set_clock_uncertainty 0.100 [get_clocks Clk]
set_input_delay 0.200 -clock Clk [remove_from_collection [all_inputs] [get_ports {Clk Rst_n}]]
set_output_delay 0.200 -clock Clk [all_outputs]
set_false_path -from [get_ports Rst_n]

