# Rendimiento: medición local

Release Windows, i7-7700HQ/Quadro M1200, Compatibility/OpenGL, 1280×720 y VSync. Un segundo de calentamiento, planificación separada y 30 segundos de ciclo más reposo. Modos medidos secuencialmente. Ambos terminaron Listo, pieza entregada y sin alarma.

| Modo | FPS medio | P50/P95/P99/máximo de frame (ms) | Solicitud inicial (ms) | Planificación (ms) |
|---|---:|---|---:|---:|
| Escritorio | 60.04 | 16.667 / 17.022 / 17.423 / 18.523 | 44.078 | 1970.336 |
| Emulación espacial | 60.02 | 16.667 / 17.012 / 17.344 / 18.683 | 57.053 | 2000.423 |

La solicitud inicial ocupa 44–57 ms en el hilo principal; no se oculta en el promedio del ciclo. El cálculo posterior usa un worker y tarda unos dos segundos. Máximos de frame durante planificación: 30.173 ms escritorio y 24.721 ms emulación.

Con VSync estos datos no miden margen de GPU ni una carga máxima. No son rendimiento VR: faltan estéreo, runtime, frecuencia real del visor y tiempos CPU/GPU. No se prometen 60 FPS en otros equipos.

Para reproducir: `scripts/Measure-Demo.ps1 -Mode Desktop` y después `-Mode Emulation`. Los JSON/capturas nuevos se guardan en `.local/validation/performance/`, fuera de Git. No medir dos modos a la vez.
