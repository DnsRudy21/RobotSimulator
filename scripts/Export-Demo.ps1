param([string]$GodotPath = "$env:USERPROFILE\tools\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe")
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $projectRoot 'exports\windows-release-immersive'
$templateDirectory = Join-Path $env:APPDATA 'Godot\export_templates\4.7.2.stable.mono'
if (([IO.File]::ReadAllText((Join-Path $templateDirectory 'version.txt'))).Trim() -ne '4.7.2.stable.mono') { throw 'Versión de templates incorrecta.' }
if (!(Test-Path -LiteralPath (Join-Path $templateDirectory 'windows_release_x86_64.exe'))) { throw 'Falta template Windows release x64.' }
New-Item -ItemType Directory -Path $destination,(Join-Path $projectRoot '.local\validation') -Force | Out-Null
$exportLog = & $GodotPath --headless --path (Join-Path $projectRoot 'godot') --export-release 'Windows Immersive' (Join-Path $destination 'RobotSimulator.exe') 2>&1
$exportCode = $LASTEXITCODE
$exportText = $exportLog -join [Environment]::NewLine
[IO.File]::WriteAllText((Join-Path $projectRoot '.local\validation\export.log'),$exportText,[Text.UTF8Encoding]::new($false))
Write-Output ($exportLog | Where-Object { "$_" -match 'Godot Engine|ERROR:|Publishing|Running dotnet publish|DONE' })
if ($exportCode -ne 0 -or $exportText -match 'ERROR:') { throw 'Release export failed; do not infer success from exe presence.' }
foreach ($name in @('GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt','DOTNET_LICENSE.txt','DOTNET_ThirdPartyNotices.txt')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot "assets\notices\$name") -Destination (Join-Path $destination $name)
}
$guide = @'
RobotSimulator — Demo educativa para Windows x64
Abrir RobotSimulator.exe y conservar todos los archivos de esta carpeta.
Escritorio: recomendado para comenzar con mouse y teclado.
Interacción espacial simulada: mouse apunta, clic selecciona, Espacio habilita
jog, botón derecho simula mirada. VR NO VALIDADA.
OpenXR: necesita runtime activo y visor/controladores PCVR; hardware pendiente.
Guía de inicio: DEMO_GUIDE.md. Ruta espacial: XR_DEMO_GUIDE.md.
Sin editor/login/conexión para ejecutar. .NET incluido. Otra PC limpia pendiente.
Conservar avisos de Godot/.NET. Seguridad y colisiones educativas.
'@
[IO.File]::WriteAllText((Join-Path $destination 'LEEME.txt'),$guide,[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\XR_HARDWARE_VALIDATION.md') -Destination (Join-Path $destination 'XR_HARDWARE_VALIDATION.md')
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\XR_DEMO_GUIDE.md') -Destination (Join-Path $destination 'XR_DEMO_GUIDE.md')

Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\DEMO_GUIDE.md') -Destination (Join-Path $destination 'DEMO_GUIDE.md')
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\DEMO_GUIDE.en.md') -Destination (Join-Path $destination 'DEMO_GUIDE.en.md')
