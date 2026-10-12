# Mapa de reutilización

Producción compartida significa usada por más de un montaje o por el montaje espacial final y el emulador; no porcentaje estimado. Conservamos una RobotSimulation por escena y un tick C# propietario.

| Componente | Cambio / clase | Consumidores | Evidencia y límites |
|---|---|---|---|
| Geometry/IK/Trajectory/TrainingCell/RobotLanguage/ProjectData/Planning/GuidedPractice | Conservados, producción compartida | Desktop, espacial, OpenXR por bridge | Regresiones originales; dominio local/colisiones educativas sin ampliación. |
| InteractionSession.cs | Nuevo, producción compartida sin Godot | Todas las fuentes | Ownership, disponibilidad, cancelación y pulsación fresca; tests Core. No permisos industriales duplicados. |
| LocalProjectRepository.cs | Nuevo, producción compartida sin Godot | Panel Proyecto espacial; bridge | Mismo JSON, nombres controlados y conflictos; permisos/corruptos no reemplazan modelo. |
| JogBridge.cs | Adaptador compartido de comandos/consultas | UI desktop/espacial/OpenXR | Misma instancia, tick y comandos; fuente/sesión/repositorio añadidos. |
| robot_world.gd | Refactor de lab.gd, producción compartida | Desktop y SpatialLab con emulación/OpenXR | Un robot/celda; escena original conserva assertions FK con actualización delegada a World. |
| lab.gd | Montaje/adaptador desktop | Escritorio y regresiones U7 | Cámara orbital y teclas/mouse aquí; no decisiones de entrada en World/InteractionSession. |
| pendant_components.gd / pendant_v2.gd | Widgets/modelo/borrador conservados | Desktop y SpatialPendant | Todas las instrucciones/referencias/puntos/celda/diagnóstico/guía. |
| spatial_pendant.gd | Montaje espacial de producción; extiende v2 | Emulación y OpenXR | Dos espacios, mismo TextEdit borrador; teclado virtual/proyectos; detalles reservan seguridad. Ancho en píxeles se sustituye por tamaño métrico configurable de Surface; Panel conserva función. |
| spatial_surface.gd / spatial_pointer.gd | Producción espacial compartida | Emulación/OpenXR | SubViewport embebido, ray→UV, captura y foco; no Input físico. Salir 18px del punto de captura cancela sin click; no drag/transferencia. |
| spatial_lab.gd / world_control.gd | Producción espacial | Emulación/OpenXR | Soporte/estación, puerta y paro por rayo conectados a bridge; configuración docente y diagnóstico en superficie. |
| openxr_adapter.gd / robot_action_map.tres | Adaptador OpenXR de producción | Windows PCVR | Rig/head/controllers/acciones/sesión, candidatos KHR simple y Oculus Touch. Sin runtime/visor real verificado. |
| entry.gd / Entry.tscn | Selector de montaje de producción | Todos | Modos explícitos; OpenXR inicia proceso con --xr-mode on antes de cargar, sin fallback silencioso. |
| spatial_emulator.gd | Única parte espacial no reutilizable en visor: emulación | Desarrollo/smoke sin visor | Cámara/puntero/Espacio y fallos F8/F9/F10. No robot, regla, intérprete o UI alternativa. |
| spatial_scenario.gd / spatial_probe.gd / immersive_test.gd / setup_action_map.gd | Fixtures/desarrollo, aislados | Pruebas y CLI de diagnóstico | Recorrido por rayo/teclado; datos de pruebas en directorios separados. Autor de mapa guarda recurso de producción y no corre al iniciar. Probes no son funciones industriales. |

Mapeo de U7: mover/enseñar/editar puntos y referencias permanecen en Mover y enseñar y detalles; todas las operaciones/estructuras y texto completo en Programa; modo/ejecución/alarma/Stop/emergencia persistentes. Proyecto usa nombres/lista en lugar de rutas; ruta administrativa permanece desktop para datos anteriores. Escenario incluye destino/pieza/pinza/banda/puerta/enclavamiento/sensor; Práctica incluye ejemplo/libre/guiado/hechos/ayuda. Diagnóstico conserva señales y hasta 500 eventos. Pose completa/ejes accesibles. Ninguna función industrial se elimina para reducir entrada.

No migración destructiva: JSON anteriores permanecen y pueden cargarse desde desktop; para acceso en superficie copie el JSON existente al directorio administrado user://projects con nombre válido. Esta operación administrativa es opcional y no requisito de una práctica nueva. No convertir ni borrar archivos anteriores. VR no probada por tener UI en 3D.
