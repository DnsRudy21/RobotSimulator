param([string]$ExportDirectory = 'exports/windows-release-immersive')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseDirectory = [IO.Path]::GetFullPath((Join-Path $projectRoot $ExportDirectory))
$packageDirectory = Join-Path $projectRoot '.local/packages'
New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null
$names = @('RobotSimulator.exe','RobotSimulator.console.exe','RobotSimulator.pck',
    'GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt','DOTNET_LICENSE.txt','DOTNET_ThirdPartyNotices.txt',
    'LEEME.txt','DEMO_GUIDE.md','DEMO_GUIDE.en.md','XR_DEMO_GUIDE.md','XR_HARDWARE_VALIDATION.md')
$paths = @()
$manifest = @()
foreach ($name in $names) {
    $path = Join-Path $releaseDirectory $name
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing release file: $name. Run Export-Demo first." }
    $paths += $path
    $hashAlgorithm = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($path)
    try { $hash = [BitConverter]::ToString($hashAlgorithm.ComputeHash($stream)).Replace('-','') }
    finally { $stream.Dispose(); $hashAlgorithm.Dispose() }
    $manifest += [pscustomobject]@{ name = $name; bytes = (Get-Item -LiteralPath $path).Length; sha256 = $hash }
}
$manifestPath = Join-Path $packageDirectory 'SHA256.json'
[IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 3),[Text.UTF8Encoding]::new($false))
$zipPath = Join-Path $packageDirectory 'RobotSimulator-demo-windows-x64.zip'
Compress-Archive -LiteralPath ($paths + $manifestPath) -DestinationPath $zipPath -CompressionLevel Optimal -Force
$zipHashAlgorithm = [Security.Cryptography.SHA256]::Create()
$zipStream = [IO.File]::OpenRead($zipPath)
try { $zipHash = [BitConverter]::ToString($zipHashAlgorithm.ComputeHash($zipStream)).Replace('-','') }
finally { $zipStream.Dispose(); $zipHashAlgorithm.Dispose() }
[IO.File]::WriteAllText(($zipPath + '.sha256'),($zipHash + '  ' + [IO.Path]::GetFileName($zipPath) + [Environment]::NewLine),[Text.UTF8Encoding]::new($false))
Write-Output "PACKAGE READY $zipPath"
Write-Output "SHA256 $zipHash"
