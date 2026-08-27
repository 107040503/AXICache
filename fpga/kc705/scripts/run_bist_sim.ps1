$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
Set-Location $projectRoot

$outputFile = Join-Path $projectRoot "fpga\kc705\sim\cache_fpga_bist.vvp"
$compileLog = Join-Path $projectRoot "fpga\kc705\sim\compile.log"
$simulationLog = Join-Path $projectRoot "fpga\kc705\sim\simulation.log"

$savedErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$compileOutput = & iverilog -g2012 -Wall -s tb_cache_fpga_bist -o $outputFile -f "fpga/kc705/sim/filelist.f" 2>&1
$compileExitCode = $LASTEXITCODE
$ErrorActionPreference = $savedErrorAction
$compileOutput | ForEach-Object { $_.ToString() } | Tee-Object -FilePath $compileLog
if ($compileExitCode -ne 0) {
    throw "KC705 BIST compile failed with exit code $compileExitCode"
}

$simulationOutput = & vvp $outputFile 2>&1
$simulationExitCode = $LASTEXITCODE
$simulationOutput | Tee-Object -FilePath $simulationLog
if ($simulationExitCode -ne 0) {
    throw "KC705 BIST simulation failed with exit code $simulationExitCode"
}
if (-not ($simulationOutput -match "KC705_BIST_SIM_PASS")) {
    throw "KC705 BIST simulation did not emit KC705_BIST_SIM_PASS"
}

Write-Host "KC705 BIST simulation passed: $simulationLog"

