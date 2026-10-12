# Estado de la ruta inmersiva

**Implementada y probada en emulación; validación con visor pendiente.**

Panel espacial, rayo/captura, teclado virtual español, proyectos JSON, celda/puerta/paro, docente, guía y diagnóstico comparten núcleo y componentes de interfaz. No hay un simulador alternativo dentro del emulador.

El adaptador OpenXR incluye rig, cámara, controladores, poses y acciones, estado de sesión y seguimiento. Los perfiles iniciales KHR simple/Oculus Touch son candidatos, no garantía de universalidad. La ausencia de runtime/visor se informa sin convertir silenciosamente la sesión en emulación.

Pérdida de cabeza/foco pausa la sesión; pérdida de controlador cancela jog, habilitación y planificación pendiente. Restauración no reanuda ni habilita por sí sola. Detener/paro conservan prioridad cuando queda una entrada útil. Estos contratos se prueban sintéticamente; falta comprobar eventos de hardware reales.

Se completó un recorrido por rayos de 344 comprobaciones y un render con 350 incluyendo capturas inspeccionadas. Escritorio/emulación se midieron aparte; no se extrapolan a VR. [Validación](VALIDATION.md) · [Rendimiento](PERFORMANCE.md).

Sin runtime activo/visor en el equipo: intentos de loader real fallaron por manifest ausente; preflight y ruta no inicializada se comprobaron bloqueadas. No se instaló runtime ni se seleccionó visor.

Próximo: hardware PCVR legítimo, controles/perfiles, sesión/tracking, recenter, lectura, comodidad y tiempos por frame. [Checklist sin resultados inventados](XR_HARDWARE_VALIDATION.md). Android autónomo sigue fuera del alcance.
