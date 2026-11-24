# Informe de verificación — SQL Quest: CyberGuard

## Hotfix: terminal de misión en la mesa

La mesa del aula se identifica con un marcador E, conserva su obstáculo y acepta interacción por proximidad desde el frente. La mesa y el botón del HUD usan el mismo flujo para abrir la misión activa, recuperar su etapa guardada o indicar que la campaña terminó. Se evitó activar el estado de trabajo antes de confirmar la apertura del laboratorio, para que cancelar el briefing no inmovilice al jugador.

Pruebas ejecutadas: `GODOT_BIN=godot tests/run_tests.sh`: 18 del simulador, 31 de campaña y 72 de integración RPG sin fallos. La integración comprueba puntos de acceso hasta la mesa, colisión, indicador, evento E, apertura de login, cancelación del briefing, salida y reapertura durante práctica y verificación, apertura de la siguiente misión, las restantes misiones y finalización. Son pruebas automatizadas en Godot headless: no constituyen un recorrido visual completo con teclado en un navegador.

Se regeneró la exportación Web y se comprobó por HTTP local la carga inicial y visibilidad del canvas. No se verificó manualmente dentro de Web cada interacción ni el diseño visual de todas las resoluciones. Godot mostró avisos de socket y objetos pendientes al cerrar las pruebas.

## Actualización: colisiones del aula y controles de audio

Se ajustaron obstáculos rectangulares independientes al arte de `classroom.png`: pizarra, estanterías, escritorio, mesas y plantas; la terminal de esa sala se situó junto al escritorio. Se sustituyeron las etiquetas pequeñas del mapa por una barra fija y mensajes contextuales. Se conectaron los reproductores a los buses Music/SFX, se añadieron controles de volumen general y activación, guardado de preferencias y atenuación durante diálogos; la música comienza al entrar a la partida.

Pruebas ejecutadas con `GODOT_BIN=godot tests/run_tests.sh`: simulador 18/18, campaña 31/31 e integración 60/60. Se comprobaron puntos dentro de la estantería izquierda, pizarra, escritorio, mueble derecho y una mesa; también un punto transitable del pasillo y acceso por proximidad a Byte y a la terminal. Se comprobaron por estado los buses y la activación/restauración de atenuación, sin verificar el sonido audible. Godot 4.7.2 exportó el proyecto a Web y se abrió la página a través de HTTP local.

Pendiente: las colisiones usan rectángulos y la función `walkable` del proyecto, no cuerpos físicos; no se han inspeccionado visualmente todos los bordes, puertas, mapas o profundidad Y en una partida real. La ilustración sigue siendo una imagen plana y no tiene capas Y-sort de muebles. No se creó una nueva banda sonora, ni se implementó un autoload global o todos los efectos solicitados; se conserva la generación musical existente. No se ha comprobado audio audible, autoplay, transiciones, preferencias ni rendimiento en navegador. La carga de la página no demuestra que se reproduzca sonido. No se realizó una nueva prueba con usuarios.

## Actualización: NPC, movimiento y estados

Diagnóstico: los NPC del mapa cambiaban fotogramas de caminata por tiempo sin desplazarse; el protagonista podía mantener `WALK` al chocar o bloquearse y el contador de pasos se reiniciaba cada fotograma; el marco gráfico del diálogo añadía líneas decorativas sobre el contenido; el estado de defensa podía quedar visualmente protegido después de alterar los bloques.

Correcciones: NPC actualmente estáticos con estados de reposo e interacción, orientación lateral de Byte usando su hoja existente; protagonista en reposo al chocar o abrir una interfaz; marco de diálogo plano; y pruebas de defensa invalidadas al cambiar bloques. Los escenarios siguen usando la rejilla de colisiones existente.

Pruebas ejecutadas: `GODOT_BIN=godot tests/run_tests.sh`: 18 comprobaciones del simulador, 31 de campaña y 50 de integración RPG, sin fallos. Incluyen reposo e interacción de Byte, bloqueo del protagonista, validación de estado al modificar la defensa y finalización de cinco misiones mediante acciones automatizadas. `git diff --check` y los diagnósticos de los scripts modificados no señalaron problemas. Exportación Web regenerada con Godot 4.7.2; carga inicial del canvas comprobada desde HTTP local.

Límites pendientes: los NPC secundarios están quietos, no cuentan con patrullas; no se ha comprobado visualmente la profundidad Y ni la correspondencia completa entre la ilustración de fondo y las colisiones de muebles. Tampoco se revisó manualmente cada resolución, cada pantalla o un recorrido completo Web con ratón/táctil. Las demostraciones de desplazamiento de datos, pruebas paso a paso y escudo siguen sin implementarse por completo. Las pruebas son headless y no sustituyen pruebas de usabilidad con estudiantes reales. Godot emitió avisos de socket y objetos sin liberar al cerrar las pruebas.

## Actualización: claridad para principiantes

Se ampliaron las explicaciones de las cinco misiones, se añadió CyberStore con una demostración de UNION y una comparación persistente de la búsqueda normal con la manipulada, un objetivo actualizado por fase, progreso y ayudas contextuales. Los separadores y controles de navegación del laboratorio usan caracteres sencillos en lugar de flechas Unicode.

Pruebas ejecutadas con Godot 4.7.2: `tests/run_tests.sh`, con 18 comprobaciones del simulador, 31 de campaña y 45 de integración RPG, todas superadas. La integración recorre la práctica normal, ataque, bloques y finalización de las cinco misiones mediante llamadas a los controles; incluye los resultados de CyberStore. Se exportó a Web y se cargó el canvas por HTTP local. No se realizó una nueva prueba con estudiantes reales ni se inspeccionó visualmente cada pantalla o resolución en el navegador; la carga inicial no demuestra que el juego completo funcione en todos los navegadores. Las animaciones siguen siendo principalmente de aparición progresiva de texto, no una representación completa de datos desplazándose entre nodos. Godot mostró avisos del socket de depuración y objetos pendientes al cerrar las pruebas headless.

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
