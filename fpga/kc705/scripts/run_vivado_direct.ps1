$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$vivado = "E:\Application\Xilinx\Vivado\2019.2\bin\vivado.bat"
$tcl = Join-Path $PSScriptRoot "build_kc705_direct.tcl"
$log = Join-Path $projectRoot "fpga\kc705\build\vivado_direct.log"
$journal = Join-Path $projectRoot "fpga\kc705\build\vivado_direct.jou"

if (-not (Test-Path $vivado)) {
    throw "Vivado 2019.2 was not found at $vivado"
}

Set-Location $projectRoot
& $vivado -mode batch -source $tcl -log $log -journal $journal
if ($LASTEXITCODE -ne 0) {
    throw "Vivado direct KC705 build failed with exit code $LASTEXITCODE. See $log"
}

Write-Host "Vivado direct KC705 build completed. Log: $log"

