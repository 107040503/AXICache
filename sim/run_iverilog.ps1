$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$outputFile = Join-Path $PSScriptRoot "tb_axi_l2_cache.vvp"
$compileLog = Join-Path $PSScriptRoot "compile.log"
$logFile = Join-Path $PSScriptRoot "simulation.log"

$savedErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$compileOutput = & iverilog -g2012 -Wall -s tb_axi_l2_cache -o $outputFile -f "sim/filelist.f" 2>&1
$compileExitCode = $LASTEXITCODE
$ErrorActionPreference = $savedErrorAction
$compileOutput | ForEach-Object { $_.ToString() } | Tee-Object -FilePath $compileLog
if ($compileExitCode -ne 0) {
    throw "Icarus Verilog compile failed with exit code $compileExitCode"
}

$simulationOutput = & vvp $outputFile 2>&1
$simulationOutput | Tee-Object -FilePath $logFile
if ($LASTEXITCODE -ne 0) {
    throw "RTL simulation failed with exit code $LASTEXITCODE"
}

if (-not ($simulationOutput -match "ALL_TESTS_PASS")) {
    throw "Simulation completed without the ALL_TESTS_PASS marker"
}

Write-Host "Simulation passed. Compile log: $compileLog"
Write-Host "Simulation log: $logFile"
