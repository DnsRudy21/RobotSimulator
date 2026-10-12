# Dónde está cada función

| Necesidad | Acceso | Comportamiento |
|---|---|---|
| Mover robot y enseñar puntos | Mover y enseñar | Manual, habilitación sostenida y dirección; referencias explícitas. |
| Configurar herramienta/referencia | Referencias… | Edita sin mover; protege referencias usadas. |
| Editar nombre/pose de un punto | Detalle / editar punto | Cambios offline; no ejecuta movimiento. |
| Escribir instrucciones | Programa / catálogo / Texto… | Un solo borrador; aplicar y verificar antes de ejecutar. |
| Subprogramas y lógica | Programa | CALL, IF/ELSE, REPEAT y esperas del lenguaje compartido. |
| Paso/ciclo/pausa/reanudar | Barra persistente | Autorización del núcleo; un plan obsoleto no inicia. |
| Detener/emergencia/reset | Barra persistente y paro del mundo espacial | Restablecer no rearranca. |
| Señales y eventos | Diagnóstico | Estado real de la celda y causa de alarmas. |
| Sensor/destino/puerta/pieza | Escenario docente | Modifica celda compartida; puede invalidar verificación. |
| Guía y ejemplo editable | Práctica y guía | Explica y registra hechos; no acredita aprendizaje. |
| Guardar/cargar | Proyecto | JSON; carga detenida, alarma conservada; sustitución explícita en ruta espacial. |
| Editar sin teclado físico | Teclado virtual espacial | Cursor, selección, números, español, confirmar/cancelar. |

La fuente de entrada puede ser escritorio, emulador o OpenXR candidato. Reglas, puntos y programas se mantienen; el emulador no implementa otra lógica de robot. [Mapa técnico](IMMERSIVE_REUSE_MAP.md).
