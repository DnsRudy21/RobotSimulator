# Exportar y empaquetar la demo Windows

El export Windows x64 incluye escritorio, emulación espacial y adaptador OpenXR candidato desde el mismo selector. Su destino es `exports/windows-release-immersive/`.

## Preparar el paquete

Se necesitan Godot .NET y plantillas oficiales coincidentes. [Entorno de desarrollo](DEVELOPMENT.md).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Export-Demo.ps1 -GodotPath "C:\ruta\Godot_console.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Smoke-Demo.ps1 -IsolatedCopy
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Package-Demo.ps1
```

El ZIP se genera en `.local/packages/RobotSimulator-demo-windows-x64.zip`. Contiene el ejecutable, PCK, wrapper de consola, cuatro avisos oficiales, instrucciones y guías. Incluye un manifiesto SHA256 y genera un hash del ZIP por separado.

## Ejecutar el paquete

Descomprime la carpeta completa y abre `RobotSimulator.exe`. No copies solamente el EXE: necesita los archivos acompañantes. No requiere instalar el editor ni .NET; el runtime está incluido. La operación funciona localmente, sin cuenta ni conexión durante la práctica.

El paquete ejecutable no incluye código fuente. Para modificar o recompilar usa la carpeta de desarrollo y los scripts indicados. Los proyectos de alumnos se guardan por separado y no forman parte del paquete.

## Qué comprueba el smoke

`-IsolatedCopy` ejecuta desde una copia temporal que contiene solo la entrega. Verifica el recorrido espacial y el bloqueo del adaptador XR no inicializado. Sigue usando la computadora de desarrollo: no equivale a otra PC limpia, y la prueba negativa XR no demuestra funcionamiento con visor. [Validación](VALIDATION.md).
