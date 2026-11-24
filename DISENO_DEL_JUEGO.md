# Dirección de diseño — SQL Quest: CyberGuard RPG

## Tesis

CyberGuard convierte una SQL Injection abstracta en una cadena visible de causa → impacto → parche → prueba dentro de un mundo RPG. El jugador explora CyberAcademy, habla con Profesor Byte y usa estaciones de laboratorio; la interfaz rechaza el formato de cuestionario aislado.

## Mundo visual

El mundo conserva pixel art sobre fondo `#0D1117`, contenedores `#161B22`, verde de confirmación `#39D353`, azul técnico `#58A6FF`, rojo de advertencia `#FF7B72` y verde de código seguro `#238636`. Al entrar en una terminal, el laboratorio usa bordes finos, esquinas redondeadas y fuente monoespaciada sin ocultar el mundo narrativo.

## Composición

La exploración muestra HUD, sala actual, misión y zonas bloqueadas. El laboratorio superpuesto tiene cuatro tarjetas: ataque, consulta construida, resultados/impacto y arreglo/regresión. El briefing de Byte ocupa su propia zona con retrato y escritura progresiva. En pantallas estrechas las tarjetas pasan a una columna mediante `GridContainer` y `ScrollContainer`, conservando primero la evidencia y después el parche.

## Interacción y movimiento

Las fases cambian por estado, no por una cadena de botones de “siguiente”. La interacción `E` abre un briefing antes de cada terminal. El ataque produce una traza con escritura progresiva y resalta el fragmento manipulado; el parche ejecuta una regresión de tres pruebas. `create_tween()` se reserva para entrada/salida, diálogo, traza, escudo y contador de puntos, sin animar tamaños administrados por contenedores. Cada movimiento tiene duración corta y se puede reducir mediante la configuración de movimiento reducido.

## Accesibilidad y seguridad

Los botones tienen estados de disabled visibles, los mensajes no dependen solo del color y el texto de código se puede editar con teclado. El laboratorio es local y sintético: no ejecuta Python, shell ni SQL externo. Las vidas se recuperan al agotarse para que el error enseñe en lugar de bloquear.
