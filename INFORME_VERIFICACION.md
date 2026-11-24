# Informe de verificación — SQL Quest: CyberGuard

## Actualización: tutor y bloques

Se ejecutó `GODOT_BIN=godot tests/run_tests.sh`: simulador 18/18, campaña 31/31 e integración RPG 28/28. Se probaron los conjuntos seguros y un distractor inseguro para cada uno de los cinco niveles. En login se comprobó añadir bloques, cambiar su orden con botones, recibir un mensaje por concatenación insegura, retirar el bloque y completar la misión.

El evaluador reconoce bloques predefinidos, comprueba dependencias entre ellos y ejecuta consultas parametrizadas y casos ficticios en el simulador interno; no ejecuta el Python mostrado ni verifica programas arbitrarios. La interacción de arrastre, el uso táctil, la presentación a distintas resoluciones, animaciones específicas de bloques y el recorrido completo de los niveles 2–5 en navegador quedan pendientes de validación manual. El tutor usa reglas locales por fase y errores de bloques, sin IA externa; no existe todavía una configuración explícita de experiencia del jugador.

## Actualización: clases interactivas

Se ejecutó `GODOT_BIN=godot tests/run_tests.sh` después de introducir las etapas de aprendizaje. Resultado: simulador 18/18, campaña 21/21 e integración RPG 26/26. La integración recorre la clase de login, exige una prueba normal y otra manipulada en la práctica guiada, comprueba que esta no concede la evidencia independiente y verifica que la misión independiente empieza sin entrada rellenada. También comprueba el reconocimiento del parche y el desbloqueo del siguiente nivel. Se regeneró la exportación Web y se comprobó mediante HTTP que el canvas es visible. Esto último comprueba la carga inicial, no una partida completa en navegador.

La validación del parche **reconoce patrones de texto**, no ejecuta el código escrito ni demuestra que sus pruebas legítimas y adversarias sean correctas. Las demostraciones usan el mismo marco y contenido específico de los cinco niveles; el recorrido de interfaz de los niveles 2–5, la comparación visual persistente entre resultados, el acceso a explicaciones anteriores desde el diario y el comportamiento responsive de todas las fases quedan pendientes de prueba manual. No se ha verificado reproducción de audio ni una publicación pública en esta actualización.

## Entorno

- Godot 4.7.2 stable en Linux.
- Renderizador Compatibility.
- Pruebas headless mediante `tests/run_tests.sh`.
- Exportación configurada para Web sin hilos.

## Pruebas ejecutadas

| Área | Resultado |
|---|---|
| Importación y carga de `scenes/main.tscn` | Superada |
| Simulador SQL acotado | 18/18 superadas |
| Campaña exclusivamente SQL Injection | 21/21 superadas |
| Integración del mundo RPG | 26/26 superadas |
| Movimiento W/A/S/D y flechas | Superada: cuatro animaciones `walk_*` |
| Idle conserva la última orientación | Superada |
| Hoja pixel-art y filtrado nearest | Superada por inspección de recurso y prueba de animaciones |
| Profesor Byte antes del laboratorio | Superada: retrato, diálogo y explicación |
| Login `admin' --` | Superada: bypass solo en simulación vulnerable |
| UNION, ORDER BY y Blind SQLi | Superadas en sus simuladores controlados |
| Editor de parche vulnerable → seguro | Superada: el editor inicia inseguro y la regresión exige una defensa válida |
| Puntuación, evidencias y desbloqueos | Superada en campaña e integración |
| Laboratorio responsive de cuatro paneles | Superada por layout con `GridContainer` y modo de una columna |
| Diagnósticos de scripts y escenas | Superada: sin errores reportados por Godot |

## Comando reproducible

```bash
GODOT_BIN=godot tests/run_tests.sh
```

Resultado observado:

```text
OK: 18 comprobaciones del simulador SQL superadas.
Campaign SQL Injection: 21 checks, 0 failures
RPG integration: 26 checks, 0 failures
```

Godot también imprime avisos del socket de depuración y objetos liberados al cerrar el proceso headless. No provocaron fallos de script ni cambiaron el código de salida de las pruebas.

## Exportación Web

La primera exportación fue bloqueada porque las plantillas Web de Godot 4.7.2 no estaban instaladas. Se instalaron temporalmente las plantillas oficiales, se regeneró la build y se comprobó que contiene `index.html`, `index.js`, `index.wasm`, `index.pck` y los worklets de audio.

Comandos de verificación:

```bash
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server 8123 --directory build/web
```

Después se debe abrir `http://127.0.0.1:8123/index.html` y comprobar el canvas, no `file://`. No se ha registrado una URL pública de Netlify, Cloudflare Pages o GitHub Pages porque no se proporcionaron credenciales.

### Resultado observado

- Servidor HTTP local: superado con PHP 8.5 en `127.0.0.1:8123`.
- Navegador: superado; cargó un canvas y `toDataURL()` devolvió una imagen no vacía de 279978 bytes.
- Redimensionamiento: superado en la comprobación del canvas para una ventana grande y una ventana estrecha; el host del navegador limita algunas vistas intermedias, pero el canvas conserva el área disponible.
- Errores de carga WebAssembly o de `.pck`: ninguno después de regenerar la exportación fuera del sandbox.

## Límites

El intérprete es una simulación segura y acotada; no es un motor SQL completo. La validación del código busca patrones semánticos específicos de cada defensa educativa y no sustituye un análisis formal de Python. El nivel Blind usa respuestas booleanas y latencias virtuales, nunca consultas externas ni exfiltración real.
