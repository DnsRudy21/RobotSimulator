# Primeros pasos con RobotSimulator

Guía para probar la demo, conocer sus controles y completar un primer ciclo. No se requiere experiencia previa con este proyecto.

## Abrir la aplicación

Con un paquete Windows, descomprimir la carpeta completa y abrir `RobotSimulator.exe`. Mantener todos los archivos acompañantes. Seleccionar **Escritorio** para comenzar con mouse y teclado; no hace falta instalar el editor ni iniciar sesión.

La descarga del código fuente no contiene el ejecutable. Para generarlo, consultar [desarrollo y compilación](DEVELOPMENT.md). El export se guarda en `exports/windows-release-immersive/`.

## 1. Cargar y explorar el ejemplo

En **Práctica y guía**, seleccionar **Cargar ejemplo editable**. El ejemplo contiene puntos y un programa de recogida y entrega de una pieza.

- **Mover y enseñar** muestra los puntos guardados y sus detalles.
- **Referencias…** permite revisar herramienta y referencia base: desde dónde se expresa el movimiento.
- **Programa** muestra la secuencia de instrucciones y su vista de texto.

La celda es totalmente virtual. El objetivo es practicar referencias, puntos, movimientos, señales y recuperación, con conceptos generales que puedan transferirse al estudiar robots de distintas marcas.

## 2. Verificar y ejecutar

1. Seleccionar **Automático** y pulsar **Verificar**.
2. Esperar el resultado; la verificación puede tardar unos segundos.
3. Pulsar **Iniciar** y observar la instrucción activa y la recogida/entrega.

**Paso** ejecuta una instrucción y pausa. **Pausa/Reanudar** suspende o continúa; **Detener** termina la ejecución. Si aparece una alarma, abrir **Diagnóstico** para consultar señales y eventos.

## 3. Probar una falla de sensor

Con la ejecución detenida, abrir **Escenario** y pulsar **Reponer celda** **antes** de activar **Introducir falla de sensor de presencia**. Volver a verificar e iniciar el ejemplo.

La espera del sensor termina en una alarma. En **Diagnóstico** se puede consultar la señal y los eventos asociados. Desactivar la falla, resolver la causa y pulsar **Restablecer**. Restablecer no rearranca: hace falta una nueva orden de inicio.

El paro, las alarmas y las colisiones son funciones educativas; no constituyen seguridad industrial certificada.

## 4. Mover y enseñar un punto

1. Con la ejecución detenida y sin alarma, seleccionar **Manual**.
2. En **Mover y enseñar**, elegir un eje y una velocidad adecuada.
3. Mantener la habilitación y un sentido de movimiento; soltar para detener.
4. Escribir un nombre y pulsar **Enseñar punto**.

En escritorio, **Espacio + ←/→** permite habilitar y elegir dirección cuando no hay un campo de texto o detalle con foco. Cambiar eje o referencia cancela la habilitación; se debe soltar y volver a pulsar. Mientras se edita texto no se permite jog.

## 5. Guardar y cargar en escritorio

Abrir **Proyecto** y pulsar **Guardar JSON**. El campo propone `user://robot-demo.json`, una ubicación de datos de la aplicación. Guardar con esa ruta sustituye el archivo existente; para conservar varias versiones se puede cambiar el nombre antes de guardar.

**Cargar JSON** recupera el proyecto de la ruta indicada. La carga queda detenida en Manual y conserva las alarmas enclavadas. Un archivo inválido no reemplaza el proyecto actual.

Guardar antes de cerrar la aplicación o cambiar de modo. Cada nueva apertura crea una sesión; el trabajo sin guardar no se transfiere automáticamente entre escritorio y modo espacial.

## 6. Probar la interacción espacial

Abrir una nueva sesión y seleccionar **Interacción espacial simulada**. Para repetir el ciclo, cargar el ejemplo desde **Práctica y guía**.

| Control | Acción |
|---|---|
| Mouse y clic | Apuntar con rayo y seleccionar. |
| Espacio mantenido | Habilitar movimiento manual. |
| Botón derecho | Simular mirada. |
| Rueda | Desplazar contenido. |

Un campo editable abre el teclado virtual con Ñ, acentos, números, cursor y selección. En **Proyecto**, escribir un nombre y pulsar **Guardar / guardar como**; si ya existe, se solicita confirmar la sustitución. Seleccionar un archivo y usar **Cargar seleccionado** para recuperarlo.

Esta modalidad funciona sin visor. El adaptador OpenXR aún necesita validación con hardware real; la emulación no demuestra compatibilidad VR. [Guía espacial](XR_DEMO_GUIDE.md).

## Continuar explorando

Modificar una instrucción o un punto y verificar de nuevo permite observar cómo cambian el recorrido y sus condiciones. La guía no acredita aprendizaje ni sustituye formación con equipos reales.

Para registrar una prueba de uso está disponible el [formulario de evaluación](HUMAN_VALIDATION.md). [Requisitos](REQUIREMENTS.md) · [Estado y límites](STATUS.md).
