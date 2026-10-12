# Ruta espacial sin visor

Selecciona **Interacción espacial simulada** al abrir la demo. Usa la misma celda, programa y reglas que escritorio; solo cambia la interacción.

| Entrada del emulador | Acción |
|---|---|
| Mouse / clic | Apuntar con rayo y seleccionar superficie o controles del mundo. |
| Espacio mantenido | Habilitación separada para jog. |
| Botón derecho | Simular mirada. |
| Rueda / botones Desplazar | Desplazar contenido. |
| F8 / F9 / F10 | Simular pérdida de sesión / seguimiento / cambio de fuente. |

Soltar y volver a pulsar después de cambiar eje, referencia, detalle o disponibilidad. Un retorno de seguimiento no habilita ni reanuda automáticamente.

1. **Proyecto → Nuevo proyecto vacío**. Selecciona herramienta y referencia en **Referencias…**; configurar no mueve.
2. **Mover y enseñar**: eje, habilitación más dirección, soltar, enseñar dos puntos. Un campo editable abre teclado virtual.
3. **Programa**: añadir instrucciones/parámetros o **Texto…** del mismo borrador. IDs conservan mayúsculas/minúsculas. Aplicar cambios antes de cambiar de programa; `main` es la entrada.
4. **Automático → Verificar → Paso/Iniciar**. Pausa/Reanudar/Detener y emergencia permanecen accesibles.
5. **Práctica y guía**: ejemplo editable. El panel docente permite preparar celda, destino, sensor y enclavamiento. Puerta/paro del mundo producen estados reales.
6. **Diagnóstico**: señales y eventos; retirar causa, restablecer y nuevo inicio. Reset no rearranca.
7. **Proyecto**: nombre, guardar/guardar como, confirmar o cancelar sustitución, cargar seleccionado. JSON administrado en `user://projects`; los proyectos anteriores no se eliminan. Copia opcional de un JSON existente a ese directorio o carga administrativa desde escritorio.
8. **Recentrar / Sentado-de pie**: ajustan observación, no referencias del robot.

Teclado: Ñ, acentos, signos, números, mayúsculas/minúsculas, espacio/salto de línea, cursor, selección, borrar, confirmar y cancelar. Mientras escribes no se permite jog; el teclado no cubre la barra de seguridad.

No hay agarre del panel, hand tracking ni locomoción continua. Para OpenXR se necesita runtime/visor PCVR disponible; mapeos y calibración todavía sin validar. [Checklist](XR_HARDWARE_VALIDATION.md).
