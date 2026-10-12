# Validación de visor — pendiente

No hay visor ni runtime activo disponible para esta entrega. Todas las celdas PASS/FAIL vacías hasta prueba humana real. Anotar visor, controladores, runtime/versión, GPU/driver, renderer, frecuencia, postura y duración. No sustituir por headless, capturas o emulación.

| Acción | Esperado | PASS/FAIL | Observaciones |
|---|---|---|---|
| Inicializar OpenXR y elegir perfil | Estéreo y fuente real identificados, sin fallback oculto | | |
| Crear proyecto desde vacío sin PC | Todos los accesos dentro del visor | | |
| Elegir/configurar TCP y referencia | Explicar unidades y efecto sin movimiento | | |
| Habilitar izquierda, seleccionar dirección derecha | Jog solo sostenido, dos controles cómodos | | |
| Soltar cada control y salir del objetivo | Se detiene sin transferencia | | |
| Perder seguimiento/controlador y recuperarlo | No rearranca ni aplica órdenes antiguas | | |
| Abrir menú del sistema/quitar visor/restaurar sesión | Pausa/cancela plan; requiere acción explícita | | |
| Enseñar dos puntos y editar offline | Pose/referencias claras; editar no mueve | | |
| Programa propio MoveJ/MoveL/WAIT/CALL/IF/REPEAT | Lenguaje completo operable, un borrador | | |
| Escribir nombres/IDs/números/texto español | Cursor/selección/borrado/confirmar/cancelar sin teclado físico | | |
| Verificar/paso/pausa/reanudar/ciclo | Estado e instrucción visibles; responde durante worker | | |
| Cambiar destino y adaptar programa | Datos y resultado varían coherentemente | | |
| Puerta/paro/sensor/diagnóstico/reset | Causa real visible; reset no inicia | | |
| Guardar/guardar como/cargar/rechazar sustitución | JSON conserva datos, sin rutas obligatorias | | |
| Archivo corrupto/permisos | Error legible; proyecto en curso conserva datos | | |
| Leer alarma/emergencia con detalle y teclado abiertos | Acceso sin apartar visor ni usar PC | | |
| Recentrar y alternar sentado/de pie | Mundo estable, referencia robot no cambia | | |
| Medir frecuencia y frame times estéreo | Presupuesto acordado según visor, percentiles/picos separados | | |
| Uso prolongado y alcance/distancia | Registrar fatiga/lectura/errores; ajustar tamaño físico | | |
| Nueva variante sin ejemplo y explicación docente | Evaluación real de transferencia/aprendizaje | | |
