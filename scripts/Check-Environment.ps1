$ErrorActionPreference = 'Continue'
Write-Host 'Diagnóstico informativo; no instala ni modifica herramientas.'
foreach ($tool in @('dotnet', 'git')) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) { & $tool --version }
    else { Write-Warning "$tool no disponible en PATH" }
}
Write-Host 'Verificar Godot .NET 4.7.2 y plantillas coincidentes para exportar.'
