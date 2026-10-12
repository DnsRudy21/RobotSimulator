# Planificación y protección de la ejecución

## Verificar sin bloquear el ciclo de presentación

`PlanningSnapshot` captura copias defensivas del modelo. `ProgramPlanner` calcula fuera de Godot; `PlanningCoordinator` administra revisión, cancelación y tareas. El hilo propietario solo acepta el resultado si corresponde al proyecto actual y está completo.

No se permite iniciar un plan parcial u obsoleto. Editar puntos, referencias, programa o celda invalida el resultado. Las ramas con un origen distinto solicitan una nueva planificación por el mismo mecanismo. Al salir se cancela y dispone el worker.

## Movimiento y entorno

FK, IK y trayectorias siguen perteneciendo al núcleo. MoveL se verifica por muestras de posición/orientación dentro del dominio local probado. La celda aplica chequeos de volumen y contactos aproximados; la envolvente pieza/pinza de 43.301 mm circunscribe la pieza cúbica de 50 mm.

El entorno puede producir alarmas y rechazo de movimiento; no se afirma dinámica física ni distancia de parada industrial. Cambiar configuración exige verificar de nuevo. Cargar un proyecto no mueve el robot ni elimina alarmas enclavadas.

## Evidencia y límites

Las suites del núcleo cubren límites, geometría, lenguaje, ciclo, fallas, cancelación y resultados obsoletos. El cálculo de planificación se mide aparte de la solicitud inicial al hilo principal; no se promete costo cero o verificación instantánea. [Validación](VALIDATION.md) · [Rendimiento](PERFORMANCE.md).

La pérdida de sesión agrega cancelación y pausa, mientras la pérdida de un controlador requerido cancela habilitación y jog. [Contratos de interacción](XR_ARCHITECTURE.md).
