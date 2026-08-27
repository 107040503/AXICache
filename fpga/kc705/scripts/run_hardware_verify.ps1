$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$vivado = "E:\Application\Xilinx\Vivado\2019.2\bin\vivado.bat"
$tcl = Join-Path $PSScriptRoot "program_and_capture_kc705.tcl"
$log = Join-Path $projectRoot "fpga\kc705\build\vivado_hardware.log"
$journal = Join-Path $projectRoot "fpga\kc705\build\vivado_hardware.jou"
$bitstream = Join-Path $projectRoot "fpga\kc705\build\kc705_axi_cache_top.bit"

if (-not (Test-Path $vivado)) {
    throw "Vivado 2019.2 was not found at $vivado"
}
if (-not (Test-Path $bitstream)) {
    throw "KC705 bitstream was not found at $bitstream. Run run_vivado_build.ps1 first."
}

Set-Location $projectRoot
& $vivado -mode batch -source $tcl -log $log -journal $journal
if ($LASTEXITCODE -ne 0) {
    throw "KC705 hardware verification failed with exit code $LASTEXITCODE. See $log"
}

Write-Host "KC705 hardware programming and ILA capture completed. Log: $log"
