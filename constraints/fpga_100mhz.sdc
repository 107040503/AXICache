# Generic 100 MHz constraint. Replace port and IO delays with the selected P1 board values.
create_clock -name Clk -period 10.000 [get_ports Clk]
set_false_path -from [get_ports Rst_n]

