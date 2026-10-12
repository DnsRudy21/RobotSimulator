# Dependencias y avisos

| Componente | Versión comprobada | Uso |
|---|---|---|
| Godot .NET | 4.7.2 stable mono, build oficial ed1daf0bf | Presentación, interfaz, SubViewport y adaptador OpenXR. |
| .NET SDK | 10.0.401 | Compilación y publicación. |
| .NET runtime | 10.0.12 en el paquete probado | Ejecución autocontenida Windows x64. |
| Godot.NET.Sdk / GodotSharp / GodotSharpEditor / Godot.SourceGenerators | 4.7.2 | Paquetes oficiales fijados en el proyecto/lockfiles. |

El núcleo C# no tiene paquetes externos; usa las bibliotecas de .NET. Los paquetes Godot provienen de `GodotSharp/Tools/nupkgs` de la distribución oficial instalada. Las plantillas de exportación deben coincidir con el editor .NET.

No hay toolkit XR añadido ni dependencias esenciales de pago. El runtime OpenXR del visor es externo al paquete y no se redistribuye ni instala automáticamente.

Los avisos oficiales Godot/.NET se conservan en [assets/notices](../assets/notices) y se copian a la entrega. No otorgan una licencia al código propio.

Fuentes: [Godot License](https://godotengine.org/license/), [Godot C#](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html), [licencia .NET runtime](https://github.com/dotnet/runtime/blob/main/LICENSE.TXT), [licencia .NET SDK](https://github.com/dotnet/sdk/blob/main/LICENSE.TXT).
