set script_path [string map {\\ /} [info script]]
set script_dir [file dirname $script_path]
set project_root [file join $script_dir .. .. ..]
set fpga_root [file join $project_root fpga kc705]
set build_root [file join $fpga_root build]
set report_dir [file join $fpga_root reports hardware]
set bit_file [file join $build_root kc705_axi_cache_top.bit]
set ltx_file [file join $build_root kc705_axi_cache_top.ltx]
set report_file [file join $report_dir hardware_verify.txt]
set csv_file [file join $report_dir kc705_bist_ila.csv]

file mkdir $report_dir
set report [open $report_file w]

proc record {handle message} {
    puts $message
    puts $handle $message
    flush $handle
}

record $report "Vivado version: [version -short]"
record $report "Board target: Kintex-7 KC705 Evaluation Platform"
record $report "Expected part: xc7k325tffg900-2"
record $report "Bitstream: $bit_file"
record $report "Debug probes: $ltx_file"

if {![file exists $bit_file]} {
    record $report "RESULT: FAIL - bitstream does not exist"
    close $report
    error "Bitstream does not exist: $bit_file"
}

open_hw_manager
connect_hw_server -url localhost:3121
open_hw_target

set targets [get_hw_targets]
set devices [get_hw_devices]
record $report "Detected targets: [llength $targets]"
foreach target $targets {
    record $report "  target: [get_property NAME $target]"
}
record $report "Detected devices: [llength $devices]"
foreach device $devices {
    record $report "  device: [get_property NAME $device], part: [get_property PART $device]"
}

set device [lindex [get_hw_devices -filter {PART =~ "xc7k325t*"}] 0]
if {$device eq ""} {
    record $report "RESULT: FAIL - KC705 FPGA was not detected over JTAG"
    close_hw_target
    disconnect_hw_server
    close_hw_manager
    close $report
    error "KC705 FPGA was not detected over JTAG"
}

set_property PROGRAM.FILE $bit_file $device
if {[file exists $ltx_file]} {
    set_property PROBES.FILE $ltx_file $device
    set_property FULL_PROBES.FILE $ltx_file $device
}

record $report "Programming device: [get_property NAME $device]"
program_hw_devices $device
refresh_hw_device $device
record $report "Program file after configuration: [get_property PROGRAM.FILE $device]"

# The top-level reset starts a self-test about 5.4 seconds after configuration.
# Capture a stable terminal snapshot after the self-test has had time to finish.
after 7000
set ilas [get_hw_ilas -of_objects $device]
record $report "Detected ILA cores: [llength $ilas]"
if {[llength $ilas] == 0} {
    record $report "RESULT: FAIL - device was programmed but no ILA core was found"
    close_hw_target
    disconnect_hw_server
    close_hw_manager
    close $report
    error "No ILA core was found after programming"
}

set ila [lindex $ilas 0]
record $report "ILA: [get_property NAME $ila]"
foreach probe [get_hw_probes -of_objects $ila] {
    record $report "  probe: [get_property NAME $probe], width: [get_property WIDTH $probe]"
}

set_property CONTROL.TRIGGER_POSITION 0 $ila
run_hw_ila $ila
wait_on_hw_ila $ila
set ila_data [upload_hw_ila_data $ila]
write_hw_ila_data -force -csv_file $csv_file $ila_data
record $report "ILA CSV: $csv_file"
record $report "RESULT: PROGRAM_AND_CAPTURE_PASS"

close_hw_target
disconnect_hw_server
close_hw_manager
close $report
exit
