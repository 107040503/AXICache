set script_path [string map {\\ /} [info script]]
set script_dir [file dirname $script_path]
set project_root [file join $script_dir .. .. ..]
puts "INFO: AXICache root = $project_root"
set fpga_root [file join $project_root fpga kc705]
set build_root [file join $fpga_root build]
set project_dir [file join $build_root vivado_project]
set report_dir [file join $fpga_root reports]

file mkdir $build_root
file mkdir $report_dir

create_project -force kc705_axi_cache $project_dir -part xc7k325tffg900-2
set_property board_part xilinx.com:kc705:part0:1.6 [current_project]
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

set rtl_files [list \
    [file join $project_root rtl cache_sram_tdp.sv] \
    [file join $project_root rtl axi_cache_slave_port.sv] \
    [file join $project_root rtl axi_master_engine.sv] \
    [file join $project_root rtl cache_core.sv] \
    [file join $project_root rtl axi_l2_cache.sv] \
    [file join $fpga_root rtl axi_bist_master.sv] \
    [file join $fpga_root rtl cache_bist_controller.sv] \
    [file join $fpga_root rtl axi_bram_memory.sv] \
    [file join $fpga_root rtl cache_fpga_bist_subsystem.sv] \
    [file join $fpga_root rtl kc705_axi_cache_top.sv]]

add_files -norecurse $rtl_files
set_property file_type SystemVerilog [get_files $rtl_files]
add_files -fileset constrs_1 -norecurse [file join $fpga_root constraints kc705_axi_cache.xdc]

create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_cache_kc705
set_property -dict [list \
    CONFIG.C_DATA_DEPTH {1024} \
    CONFIG.C_NUM_OF_PROBES {8} \
    CONFIG.C_PROBE0_WIDTH {8} \
    CONFIG.C_PROBE1_WIDTH {8} \
    CONFIG.C_PROBE2_WIDTH {8} \
    CONFIG.C_PROBE3_WIDTH {32} \
    CONFIG.C_PROBE4_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {32} \
    CONFIG.C_PROBE6_WIDTH {32} \
    CONFIG.C_PROBE7_WIDTH {32} \
    CONFIG.C_ADV_TRIGGER {true} \
    CONFIG.C_INPUT_PIPE_STAGES {1}] [get_ips ila_cache_kc705]
generate_target all [get_ips ila_cache_kc705]

set_property verilog_define {XILINX_ILA} [get_filesets sources_1]
set_property top kc705_axi_cache_top [get_filesets sources_1]
update_compile_order -fileset sources_1

set_property strategy Flow_PerfOptimized_high [get_runs synth_1]
set_property strategy Performance_Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

puts "INFO: launching KC705 synthesis"
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "KC705 synthesis failed: [get_property STATUS [get_runs synth_1]]"
}

open_run synth_1
report_utilization -hierarchical -file [file join $report_dir post_synth_utilization.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -max_paths 20 \
    -file [file join $report_dir post_synth_timing_summary.rpt]
close_design

puts "INFO: launching KC705 implementation and bitstream"
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
    error "KC705 implementation failed: [get_property STATUS [get_runs impl_1]]"
}

open_run impl_1
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
    -max_paths 20 -file [file join $report_dir timing_summary.rpt]
report_utilization -hierarchical -file [file join $report_dir utilization_hierarchical.rpt]
report_utilization -file [file join $report_dir utilization.rpt]
report_clock_utilization -file [file join $report_dir clock_utilization.rpt]
report_power -file [file join $report_dir power.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_methodology -file [file join $report_dir methodology.rpt]

set setup_path [get_timing_paths -delay_type max -max_paths 1]
set hold_path [get_timing_paths -delay_type min -max_paths 1]
set setup_wns [get_property SLACK $setup_path]
set hold_wns [get_property SLACK $hold_path]

set bit_source [file join $project_dir kc705_axi_cache.runs impl_1 kc705_axi_cache_top.bit]
set bit_target [file join $build_root kc705_axi_cache_top.bit]
file copy -force $bit_source $bit_target

set ltx_target [file join $build_root kc705_axi_cache_top.ltx]
write_debug_probes -force $ltx_target

set summary_file [open [file join $report_dir build_summary.txt] w]
puts $summary_file "Vivado version: [version -short]"
puts $summary_file "Board: Kintex-7 KC705 Evaluation Platform"
puts $summary_file "Part: xc7k325tffg900-2"
puts $summary_file "Top: kc705_axi_cache_top"
puts $summary_file "Target cache clock: 100.000 MHz"
puts $summary_file "Implementation status: [get_property STATUS [get_runs impl_1]]"
puts $summary_file "Setup WNS: $setup_wns ns"
puts $summary_file "Hold WHS: $hold_wns ns"
puts $summary_file "Bitstream: $bit_target"
puts $summary_file "Debug probes: $ltx_target"
close $summary_file

puts "RESULT: setup WNS = $setup_wns ns"
puts "RESULT: hold WHS = $hold_wns ns"
puts "RESULT: bitstream = $bit_target"
puts "RESULT: probes = $ltx_target"

if {$setup_wns < 0.0} {
    error "100 MHz setup timing failed: WNS=$setup_wns ns"
}
if {$hold_wns < 0.0} {
    error "Hold timing failed: WHS=$hold_wns ns"
}

close_project
exit
