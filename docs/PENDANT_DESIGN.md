# Diseño del panel de programación

## Dos tareas principales

**Mover y enseñar** reúne selección de eje, referencias, habilitación, dirección y puntos. **Programa** reúne secuencia, instrucciones, parámetros y edición de texto. Las dos vistas editan los mismos datos; no hay un programa diferente por interfaz.

La barra persistente muestra modo, estado, detener, emergencia virtual, velocidad, verificar/iniciar/paso/pausa-reanudar, referencia y herramienta. Restablecer aparece cuando hay alarma. Cerrar un detalle no borra alarmas ni reanuda.

## Información cuando hace falta

Pose completa, ejes, referencias y edición de puntos se abren en detalles. Diagnóstico conserva señales y eventos; la guía explica fundamentos. En escritorio el área general contiene proyectos, escenario docente y práctica. En la ruta espacial esas mismas funciones están dentro de la superficie.

Los detalles y teclado ocupan el lado izquierdo para conservar acceso a detener/emergencia a la derecha. Las listas largas desplazan. Abrir un detalle, editar texto o cambiar eje/referencia cancela habilitación: volver al panel no rearma.

## Reutilización y alcance

`pendant_v2.gd` reutiliza `pendant_components.gd`; `spatial_pendant.gd` extiende esa interfaz con teclado virtual y archivos administrados. Todos envían comandos al mismo bridge y núcleo. El nombre v2 identifica el componente vigente; la versión anterior sin uso no se incluye en el proyecto activo.

El tamaño de escritorio y el tamaño métrico espacial son distintos. La legibilidad en monitor se inspeccionó; comodidad y distancia en visor no están validadas. Menos navegación no demuestra por sí sola menor carga cognitiva o aprendizaje. [Checklist humano](HUMAN_VALIDATION.md).
