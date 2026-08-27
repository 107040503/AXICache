set script_path [string map {\\ /} [info script]]
set script_dir [file dirname $script_path]
set project_root [file join $script_dir .. .. ..]
set fpga_root [file join $project_root fpga kc705]
set build_root [file join $fpga_root build direct]
set report_dir [file join $fpga_root reports direct]

file mkdir $build_root
file mkdir $report_dir

set_param general.maxThreads 1
set_msg_config -id {Synth 8-5788} -limit 20

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

foreach rtl $rtl_files {
    read_verilog -sv $rtl
}

puts "INFO: direct synthesis starts"
synth_design -top kc705_axi_cache_top -part xc7k325tffg900-2 \
    -flatten_hierarchy rebuilt -directive Default
read_xdc [file join $fpga_root constraints kc705_axi_cache.xdc]
write_checkpoint -force [file join $build_root post_synth.dcp]
report_utilization -hierarchical -file [file join $report_dir post_synth_utilization.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -max_paths 20 \
    -file [file join $report_dir post_synth_timing_summary.rpt]

puts "INFO: opt_design starts"
opt_design
write_checkpoint -force [file join $build_root post_opt.dcp]

puts "INFO: place_design starts"
place_design -directive Explore
phys_opt_design -directive Explore
write_checkpoint -force [file join $build_root post_place.dcp]
report_timing_summary -delay_type min_max -max_paths 20 \
    -file [file join $report_dir post_place_timing_summary.rpt]

puts "INFO: route_design starts"
route_design -directive Explore
phys_opt_design -directive Explore
write_checkpoint -force [file join $build_root post_route.dcp]

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
set hold_whs [get_property SLACK $hold_path]

set bit_target [file join $build_root kc705_axi_cache_top.bit]
write_bitstream -force $bit_target

set summary_file [open [file join $report_dir build_summary.txt] w]
puts $summary_file "Vivado version: [version -short]"
puts $summary_file "Board: Kintex-7 KC705 Evaluation Platform"
puts $summary_file "Part: xc7k325tffg900-2"
puts $summary_file "Top: kc705_axi_cache_top"
puts $summary_file "Target cache clock: 100.000 MHz"
puts $summary_file "Flow: direct non-project synthesis/implementation"
puts $summary_file "ILA: not included in this diagnostic build"
puts $summary_file "Setup WNS: $setup_wns ns"
puts $summary_file "Hold WHS: $hold_whs ns"
puts $summary_file "Bitstream: $bit_target"
close $summary_file

puts "RESULT: setup WNS = $setup_wns ns"
puts "RESULT: hold WHS = $hold_whs ns"
puts "RESULT: bitstream = $bit_target"

if {$setup_wns < 0.0} {
    error "100 MHz setup timing failed: WNS=$setup_wns ns"
}
if {$hold_whs < 0.0} {
    error "Hold timing failed: WHS=$hold_whs ns"
}

exit
