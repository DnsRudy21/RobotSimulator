# Desarrollo y compilación

## Herramientas

- Windows x64 y PowerShell.
- Godot **.NET 4.7.2**, no la edición sin C#.
- .NET SDK **10.0.401**; `global.json` permite parches posteriores de esa banda.
- Para exportar: plantillas oficiales **4.7.2 stable mono** coincidentes y restauración del runtime .NET necesario.

No hace falta Git LFS, Blender, un visor o una cuenta para compilar y probar el núcleo. La configuración inicial de herramientas y el restore de exportación pueden necesitar Internet; la demo ejecutable funciona localmente.

## Abrir y probar

Importa `godot/project.godot` en Godot .NET. F5 abre el selector de modos; la escena principal es `Entry.tscn`.

```powershell
dotnet run --project tests/RobotSimulator.Core.Tests
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Build-And-Test.ps1 -GodotPath "C:\ruta\Godot_console.exe"
```

El script restaura los paquetes oficiales desde `GodotSharp/Tools/nupkgs` de la instalación indicada, compila y ejecuta las suites del núcleo e interfaz. Comprueba tanto el código de salida como errores reportados por Godot. Bypass se limita a ese proceso, sin cambiar la política global.

## Exportar, comprobar y empaquetar

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Export-Demo.ps1 -GodotPath "C:\ruta\Godot_console.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Smoke-Demo.ps1 -IsolatedCopy
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Package-Demo.ps1
```

El export se genera en `exports/windows-release-immersive/` y contiene los tres modos del selector. Logs, mediciones y ZIP se guardan bajo `.local/`; son resultados generados, no archivos fuente. El ZIP incluye toda la entrega ejecutable, sin código fuente ni archivos de desarrollo.

Las mediciones se ejecutan secuencialmente con `scripts/Measure-Demo.ps1 -Mode Desktop` y `-Mode Emulation`. Generan evidencia local, no rendimiento VR.

## Organización

| Carpeta | Responsabilidad |
|---|---|
| `src/RobotSimulator.Core` | Geometría, lenguaje, estados, planificación, celda, proyectos y práctica. |
| `godot/scripts` y `godot/scenes` | Presentación y adaptación de entradas; no duplican el núcleo. |
| `tests` y `godot/tests` | Pruebas de matemáticas, estados, errores e interacción. |
| `docs` | Guías y documentación vigente. |
| `assets/notices` | Avisos oficiales de las dependencias distribuidas. |
| `exports` y `.local` | Ejecutable, paquetes y evidencia solo local. |

## Reglas de contribución

Interfaz del alumno en español; identificadores claros en inglés. Mantener el núcleo independiente de Godot y un solo propietario del paso de simulación. Probar estados/errores relevantes, registrar límites y no introducir dependencias de pago esenciales. Todo recurso externo necesita origen y licencia en `assets/ATTRIBUTIONS.md`.

La licencia del código propio permanece sin definir; consultar al propietario antes de redistribuir o reutilizarlo.
