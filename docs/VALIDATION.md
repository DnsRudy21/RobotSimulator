# Qué se ha comprobado

## Base funcional

- 34 grupos del núcleo: 31 de matemáticas/controlador/lenguaje/celda/planificación más 3 de interacción, repositorio y sesión/worker.
- Regresiones de escena, panel e interfaz, incluyendo 74 comprobaciones del rediseño del panel.
- Recorrido espacial: 344 comprobaciones sin fallos; 350 en el recorrido con seis capturas de render, inspeccionadas.
- Export autocontenido comprobado mediante una copia de solo la entrega y rutas de diagnóstico acotadas.
- Mediciones independientes de escritorio/emulación y capturas del ejecutable inspeccionadas.

El recorrido espacial utiliza rayos sobre controles: proyecto vacío, referencias, jog, dos puntos, programa propio con movimientos/esperas/CALL/IF/REPEAT/señales, paso, ciclo, edición numérica, falla de sensor, diagnóstico/reset y guardar/cargar. No se limita a llamar al modelo de la interfaz.

Las pruebas espaciales controlan la disponibilidad de forma sintética y aíslan entrada/foco físicos del emulador. Verifican contratos de cancelación y recuperación, no seguimiento real de manos/cabeza. El núcleo sigue siendo autoridad de movimiento.

## VR no disponible

Preflight local sin runtime registrado; mapa con un conjunto/dos perfiles cargado. El adaptador sin inicializar informa indisponibilidad y bloquea movimiento. Intentos con el loader real fallaron por manifest/runtime ausente y se interrumpieron; no son pruebas XR exitosas.

No hay resultados de estéreo, mapeos físicos, tracking real, sesión real, recenter, comodidad/frecuencia VR, aprendizaje o segunda PC limpia. Checklists humano/visor permanecen pendientes.

## Reproducibilidad

La copia recién clonada del código fuente compiló sin errores/advertencias y pasó las suites completas, incluido el recorrido espacial. Se usaron las herramientas del mismo equipo; no equivale a una prueba en otra PC limpia.

Los scripts utilizan Godot y .NET directamente. [Instrucciones de desarrollo](DEVELOPMENT.md) · [Estado](STATUS.md).
