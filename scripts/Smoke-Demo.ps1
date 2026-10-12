param([string]$ExportDirectory='exports/windows-release-immersive',[switch]$IsolatedCopy)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$source=[IO.Path]::GetFullPath((Join-Path $root $ExportDirectory))
if(!(Test-Path -LiteralPath (Join-Path $source 'RobotSimulator.console.exe'))) { throw 'Missing complete release.' }
$target=$source
if($IsolatedCopy) {
    $target=Join-Path ([IO.Path]::GetTempPath()) ('RobotSimulator-immersive-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $target | Out-Null
    Copy-Item -LiteralPath $source -Destination (Join-Path $target 'release') -Recurse
    $target=Join-Path $target 'release'
}
Write-Output "SMOKE DIRECTORY $target"
$executable=Join-Path $target 'RobotSimulator.console.exe'
foreach($arguments in @(@('--headless','--','--spatial-smoke'),@('--headless','--','--xr','--xr-smoke'))) {
    $output=& $executable @arguments 2>&1
    $code=$LASTEXITCODE
    $text=$output -join [Environment]::NewLine
    Write-Output $text
    if($code -ne 0 -or $text -match 'ERROR:') { throw 'Immersive smoke failed.' }
    if($arguments -contains '--spatial-smoke' -and $text -notmatch 'SPATIAL checks=\d+ failures=0') {throw 'Spatial completion marker missing.'}
    if($arguments -contains '--xr-smoke' -and $text -notmatch 'XR UNAVAILABLE:') {throw 'XR unavailable test condition did not occur.'}
}
Write-Output 'IMMERSIVE STANDALONE SMOKE PASS (emulation and unavailable XR; no hardware)'
