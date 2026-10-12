# Contrato matemático y de lenguaje

Controlador didáctico propio. No importa programas de fabricantes ni certifica seguridad, fuerzas, precisión industrial o aprendizaje. Núcleo C# independiente de Godot; sin paquetes matemáticos, frameworks de pruebas o servicios nuevos.

La planificación vigente usa snapshots privados, revisión y cancelación, descritas en [CONSOLIDATION](CONSOLIDATION.md). La envolvente pieza/pinza actual es de 43.301 mm; referencias inferiores a 35 mm documentan el modelo inicial. Rendimiento y exportación vigentes están en PERFORMANCE y EXPORT.

## Geometría, poses y referencias (R01/R03/R04/R06)

`RobotGeometry.Joints` es la fuente de orígenes, ejes y límites; Core/jog/FK y escena la consumen. Se conservan las dimensiones M1. La brida es el origen J6; su placa visual mide 70 mm. Dobles en Core, float únicamente al cruzar Godot. Metros/radianes/segundos; UI mm/grados. Z arriba en Core; conversión (x,y,z) → (x,z,−y) a Godot. Cuaterniones unitarios, composición padre × traslado × rotación articular, signo por mano derecha. RPY visible: Rz(yaw) × Ry(pitch) × Rx(roll), con la ambigüedad habitual en ±90° de pitch; el cuaternión sigue siendo la orientación almacenada.

Pose brida: composición de los seis eslabones. Pose TCP mundo = brida × TCP local. Pose expresada = frame⁻¹ × TCP mundo. La base es fija; frame pieza y otros IDs son poses respecto a base. Cambiar selección/crear TCP o frame no mueve articulaciones. Referencia usada por puntos no se edita: crear otro ID o retirar/reenseñar los puntos. Se almacenan ID de punto, nombre, tipo, seis articulaciones/configuración, pose local, ID de TCP y frame. MOVEJ articulares usa ángulos; puntos cartesianos usan pose completa y semilla de configuración. Editar un punto no mueve el robot. Borrar un punto usado en programas se rechaza.

La pinza física permanece montada a +120 mm X de brida. Seleccionar otro TCP es una selección lógica, no un cambio físico de herramienta: agarre y pieza sostenida se calculan con esa pinza física, evitando un agarre remoto por TCP mal configurado. El pequeño marcador cian muestra el TCP lógico seleccionado. No hay herramientas intercambiables implementadas.

IK: mínimos cuadrados amortiguados locales, jacobiano numérico 6×6, posición y orientación; semilla actual, límites por eje, búsqueda de paso decreciente, máximo 240 iteraciones por solución. No es un solucionador global de todas las ramas. Aceptación matemática fijada antes de probar: ≤0.1 mm y ≤0.1°. Criterio interno de convergencia más estricto: ≤0.01 mm y ≤0.0001 rad. Inalcanzable/no convergencia conserva semilla y se rechaza. Jog cartesiano además exige incremento articular ≤30°/s × dt ×1.05; un objetivo cerca de límite/singularidad puede detenerse en vez de cambiar de rama. Dominio probado: configuraciones cercanas a cero y las no singulares del ejemplo; no se garantiza todo el espacio de trabajo.

Jog cartesiano XYZ sigue los ejes del frame activo; Rx/Ry/Rz son incrementos de rotación alrededor de esos ejes (no suma de Euler). Máximos 50 mm/s y 15°/s con override. Manual + foco + habilitación mantenida + ausencia de causas + reset. Liberación/foco cancelan sin salto. No mover por teclado mientras un campo de texto tenga foco.

## Lenguaje, programación y trayectorias (P02–P06/R05)

Programa por líneas, decimal con punto, `#` comentario. IDs ASCII de hasta 64 caracteres; no evalúa C# ni GDScript. Ejemplo completo editable cargable desde Guía, más programa vacío. TextEdit permite edición libre y botones insertar/borrar/subir/bajar línea; guardar por ID permite subprogramas. El programa de inicio es `main`.

| Instrucción | Semántica |
|---|---|
| MOVEJ punto_ID duración_s | Interpolación articular, terminación exacta; punto articular o pose cartesiana resuelta localmente. |
| MOVEL punto_ID duración_s | Línea TCP y orientación por arco más corto de cuaterniones, resuelta localmente con continuidad y límites. |
| SET_OUTPUT grip\|belt 0\|1 | Acción de dispositivo: pinza física o banda. Agarre inválido produce alarma; no ignora error. |
| WAIT_INPUT señal 0\|1 timeout_s | Estado vivo de la simulación; timeout obligatorio 0.01…120 s. |
| WAIT duración_s | Tiempo simulado 0.01…120 s; no tiempo de pared. |
| IF señal 0\|1 / ELSE / ENDIF | Una rama según señal en ese momento; ELSE opcional. |
| REPEAT n / ENDREPEAT | Entero 1…100, producto anidado ≤10000. |
| CALL programa_ID | Expansión acotada; recursión prohibida, profundidad ≤8. |

Señales: present, holding, delivered, grip, belt. Solo grip/belt son salidas. Máximo 32 bloques anidados, 10000 instrucciones expandidas, 32 programas y 32000 caracteres por programa. Cierres y operaciones desconocidas se rechazan con ubicación programa:línea. Una compilación vacía termina sin mover. No hay blending.

Planificación normalizada s; tiempo con perfil quintic `10t³−15t⁴+6t⁵`, cero velocidad/aceleración en extremos. Límite articular 30°/s, presupuesto 60°/s²; se reserva mitad para rampa de override a 0.5/s. La duración pedida es un mínimo 0.1…120 s: el plan la alarga para cumplir límites, o rechaza si necesita >120 s. MOVEL genera muestras cada ≤1 mm / ≤0.002 rad (también por cambio articular), máximo 2000; IK en cada muestra y comprobación de medios de intervalo. Más de 0.04 rad entre muestras o exceso de tolerancias rechaza. La ejecución interpola tabla y muestrea colisión adicional. Sin promesa de exactitud analítica entre infinitos puntos ni determinismo físico. Paso aceptado 0<dt≤0.1 s; operación de escena 60 Hz. Pruebas incluyen recorridos densos e integración temporal.

Verificar/Inicio validan estructura y recorridos desde la postura actual. Preflight revisa conservadoramente ambas ramas en orden textual; puede rechazar programas que necesitarían análisis de flujo más complejo. Cada movimiento real verifica su origen: reutiliza el plan validado si coincide a 1e−8 rad; de lo contrario replantea/revalida antes de mover. Edición bloqueada durante ejecución o pausa; cambiar modo hace Stop. La instrucción activa muestra ubicación, incluyendo CALL expandido. Paso completa una instrucción y pausa. IF/JUMP pueden consumir un tick para cambiar de rama.

Pausa congela tiempo/pose y detiene banda; Iniciar/Paso reanudan solo por acción explícita y desde la pose registrada. Si se altera pose, se exige Stop y verificar de nuevo. Belt no se restaura automáticamente al reanudar: vuelva a ejecutar SET_OUTPUT si el programa necesita banda. Stop cancela trayectoria y contexto, detiene banda, conserva pieza sostenida y posición, y un nuevo Inicio parte de la primera instrucción desde la pose actual. Paro, pausa, foco y emergencia son cancelaciones instantáneas educativas, no frenado físico ni distancias seguras. Solo los movimientos normales usan el perfil suave.

## Celda, colisiones y seguridad (M01 parcial/M02/S01–S04/R07)

Conveyor visible con travel proveniente de Core, motor 0.1 m/s en +Y base, sensor present cuando pieza a <55 mm del punto de recogida, banda parada en primera recogida. Pinza: pieza existente, banda parada, distancia ≤40 mm, error angular ≤15°. Sin fuerzas/fricción. Pieza cerrada sigue pinza física; al abrir queda en pose actual (sin caída dinámica); delivered si a ≤80 mm de destino. Cambiar el punto y la estación cambia el resultado; no hay animación de ciclo precalculada. Una pieza por celda; reponer es acción detenida explícita.

Colisión: suelo; AABB de estaciones (recogida ±110 mm X / ±220 mm Y, destino ±110 mm XY, desde suelo hasta centro pieza−45 mm); obstáculo cubo 200 mm. Brazo por cadena de esferas cada ≤10 mm, radios por volumen 120/100/90/60/50/25 mm, margen 5 mm al consultar AABB. Envolvente de pinza/pieza de 35 mm comprobada incluso antes de recoger. Son volúmenes aproximados; no coincide cada vértice de la malla. Pares de autocolisión definidos (0,4),(0,5),(1,4),(1,5), excluye pares contiguos. Barrido entre pasos a ≤0.002 rad por eje; preflight revisa muestras de trayectoria. No certifica ausencia de colisión para mallas exactas, todas las parejas ni obstáculos externos. Ejercicio independiente comprueba obstáculo entre extremos libres.

Puerta cerrada requerida con enclavamiento activo en manual/automático. Emergencia bloquea ambos. Retirar enclavamiento solo detenido y registra PRÁCTICA DE RIESGO; abrir puerta así registra RIESGO, no equivale a una colisión. Causa activa bloquea Reset. Retirar causa no cambia Faulted/EmergencyStopped a Running; Reset elimina contexto y habilitación y exige nueva acción. Pérdida de foco cancela manual y pausa automático sin reanudar al regresar. I/O y registro con tiempo simulado, máximo 500 eventos, UI últimos 40. Alarmas de timeout, colisión, agarre y permiso explicables. Interlock/emergencia/estado activo no se guardan en JSON.

## Persistencia y práctica (P06/Q01 parcial)

JSON `SchemaVersion=1`, `RobotId=generic-six-axis-v1`; robot identifica geometría fija soportada, no se importa geometría arbitraria. Guarda TCP/frames, IDs, puntos, programas y configuración de celda. Máximo 1 MB, 500 puntos y 32 referencias por tipo; propiedades obligatorias, desconocidas/versiones/valores no finitos rechazados. No guarda ejecución, habilitación ni posición actual; cargar conserva pose de robot, repone celda, entra manual detenido con enclavamiento vigente (no anula causas externas). Carga inválida no sustituye el proyecto. Escritura a temporal único y reemplazo en el mismo directorio; errores de archivo/permisos se muestran. La ruta de UI admite `user://` o ruta Windows del alumno. Requiere programa estructuralmente válido al guardar; borradores inválidos permanecen en editor hasta corregirse.

Libre permite soluciones propias. Guía inicia evidencia nueva: seleccionar referencias, enseñar, modificar programa, verificar, terminar un paso, entregar por programa, registrar falla, recuperar, guardar y cargar. Marca solo acciones exitosas/estado observable; cargar ejemplo no marca enseñanza/programación propias. No es una calificación pedagógica ni comprobación de comprensión. Acepta puntos/programas distintos si entregan la pieza. Docente/alumnos aún no probaron la demo.

## Fuera de alcance

VR, soldadura, visión y editor amplio pendientes, sin botones ficticios. Interfaces ISignalDevice/ICollisionScene y reservas de visión/proceso permiten ampliación; no implementación de PLC, nube, IA generativa o multijugador. Sin validación en instalaciones reales ni hardware XR.
