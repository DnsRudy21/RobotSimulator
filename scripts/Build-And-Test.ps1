param([string]$GodotPath = "$env:USERPROFILE\tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe")
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (!(Test-Path -LiteralPath $GodotPath)) { throw "Godot .NET no encontrado: $GodotPath. Pase -GodotPath con la ruta instalada." }
$packages = Join-Path (Split-Path -Parent $GodotPath) 'GodotSharp\Tools\nupkgs'
if (!(Test-Path -LiteralPath (Join-Path $packages 'Godot.NET.Sdk.4.7.2.nupkg'))) { throw 'Se requieren los paquetes oficiales de Godot .NET 4.7.2.' }
function Invoke-VerifiedGodot([string[]]$EngineArguments) {
    $engineOutput = & $GodotPath @EngineArguments 2>&1
    $engineCode = $LASTEXITCODE
    $engineText = $engineOutput -join [Environment]::NewLine
    Write-Output $engineText
    if ($engineCode -ne 0 -or $engineText -match 'ERROR:') { throw 'Godot informó error de ejecución/importación; exit0 no basta.' }
}
Push-Location $projectRoot
try {
    & dotnet build godot/RobotSimulator.csproj "-p:RestoreSources=$packages" -p:RestoreLockedMode=true
    if ($LASTEXITCODE) { throw 'Falló la compilación.' }
    & dotnet run --project tests/RobotSimulator.Core.Tests
    if ($LASTEXITCODE) { throw 'Fallaron las pruebas del núcleo.' }
    Invoke-VerifiedGodot -EngineArguments @('--headless','--path','godot','--editor','--quit')
    if ($LASTEXITCODE) { throw 'Falló la importación.' }
    Invoke-VerifiedGodot -EngineArguments @('--headless','--path','godot','--script','res://tests/scene_test.gd')
    if ($LASTEXITCODE) { throw 'Fallaron las pruebas de escena.' }
    Invoke-VerifiedGodot -EngineArguments @('--headless','--path','godot','--script','res://tests/pendant_test.gd')
    if ($LASTEXITCODE) { throw 'Fallaron las pruebas de pendant.' }
    Invoke-VerifiedGodot -EngineArguments @('--headless','--path','godot','--script','res://tests/consolidation_ui.gd')
    if ($LASTEXITCODE) { throw 'Falló recorrido UI de consolidación.' }
    Invoke-VerifiedGodot -EngineArguments @('--headless','--path','godot','--script','res://tests/pendant_redesign_test.gd')
    if ($LASTEXITCODE) { throw 'Falló recorrido U6 de rediseño.' }
    Invoke-VerifiedGodot -EngineArguments @('--headless','--path','godot','--script','res://tests/immersive_test.gd','--quit-after','18000')
    if ($LASTEXITCODE) { throw 'Falló recorrido espacial I8.' }
} finally { Pop-Location }
