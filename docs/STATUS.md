# Estado de la demo

Última revisión: 11 de octubre de 2026.

## Implementado

Robot virtual de seis ejes con movimiento articular/cartesiano, enseñanza de puntos, referencias, programa editable, señales, celda y recuperación de fallas. Escritorio y ruta espacial comparten núcleo C# y mundo.

La ruta espacial incluye selección por rayo, teclado virtual español, proyectos JSON, controles de puerta/paro, panel docente, guía y diagnóstico. El adaptador OpenXR PCVR es candidato: su funcionamiento con visor aún no está validado.

## Probado

- Compilación sin errores ni advertencias, también desde una copia recién clonada del código fuente.
- 34 grupos de pruebas del núcleo y suites de interfaz, incluyendo 74 comprobaciones del panel.
- Recorrido espacial de 344 comprobaciones sin fallos; render con 350 incluyendo seis capturas inspeccionadas.
- Export autocontenido y prueba desde copia de solo la entrega: recorrido espacial y bloqueo XR sin inicializar.
- ZIP verificado por integridad y SHA256 contra los archivos del ejecutable probado.
- Enlaces de documentación, imágenes, JSON/XML y sintaxis de los scripts comprobados.

Las mediciones de escritorio y emulación están separadas en [PERFORMANCE](PERFORMANCE.md). Las pruebas de disponibilidad son sintéticas y no acreditan operación real con visor o aprendizaje.

## Limitaciones

Cinemática inversa local, agarre y colisiones aproximados, sin seguridad industrial certificada ni control de equipos físicos. No hay resultados de otra PC limpia, seguimiento/sesión reales, comodidad en visor ni aprendizaje validado. [Alcance](REQUIREMENTS.md) · [Estado XR](XR_STATUS.md).

## Próximo paso

Completar un recorrido con docentes, registrar dificultades y probar el paquete en otra PC. Cuando exista hardware PCVR disponible, realizar el [checklist de visor](XR_HARDWARE_VALIDATION.md) antes de afirmar compatibilidad.
