# Synopsys Design Compiler template. Set both environment variables before running:
#   ASIC_LIB_DIR     directory containing the technology .db library
#   ASIC_TARGET_LIB  target .db filename, for example typical.db

if {![info exists ::env(ASIC_LIB_DIR)]} {
    error "ASIC_LIB_DIR is not set"
}
if {![info exists ::env(ASIC_TARGET_LIB)]} {
    error "ASIC_TARGET_LIB is not set"
}

file mkdir build
file mkdir reports

set_app_var search_path [concat $search_path [list ./rtl $::env(ASIC_LIB_DIR)]]
set_app_var target_library [list $::env(ASIC_TARGET_LIB)]
set_app_var link_library [concat "*" $target_library]

set rtl_files [list \
    rtl/cache_sram_tdp.sv \
    rtl/axi_cache_slave_port.sv \
    rtl/axi_master_engine.sv \
    rtl/cache_core.sv \
    rtl/axi_l2_cache.sv]

analyze -format sverilog $rtl_files
elaborate axi_l2_cache
current_design axi_l2_cache
link
check_design > reports/dc_check_design.rpt

source constraints/asic_500mhz.sdc
set_fix_multiple_port_nets -all -buffer_constants
compile_ultra

report_qor > reports/dc_qor.rpt
report_area -hierarchy > reports/dc_area.rpt
report_timing -delay_type max -max_paths 20 > reports/dc_timing_max.rpt
report_timing -delay_type min -max_paths 20 > reports/dc_timing_min.rpt
report_constraint -all_violators > reports/dc_constraints.rpt

write -format verilog -hierarchy -output build/axi_l2_cache_mapped.v
write_sdc build/axi_l2_cache_mapped.sdc
write -format ddc -hierarchy -output build/axi_l2_cache_mapped.ddc

