param([ValidateSet('Desktop','Emulation')][string]$Mode='Emulation')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$directory=Join-Path $root '.local\validation\performance'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$executable=Join-Path $root 'exports\windows-release-immersive\RobotSimulator.console.exe'
$arguments=@('--',"--metrics-dir=$directory")
if($Mode -eq 'Desktop') { $arguments+='--probe-release' } else { $arguments+='--probe-spatial' }
$output=& $executable @arguments 2>&1
$code=$LASTEXITCODE
$text=$output -join [Environment]::NewLine
Write-Output $text
if($code -ne 0 -or $text -match 'ERROR:' -or $text -notmatch 'PERFORMANCE') { throw 'Probe failed; do not infer VR performance.' }
