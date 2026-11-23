# SQL QUEST: FROM ZERO TO CYBER HERO

Aventura educativa **jugable en Godot 4.3+**, escrita en GDScript. Explora CyberAcademy, escribe SQL, investiga aplicaciones ficticias, repara consultas y supera una entrevista práctica. La campaña principal tiene **ocho misiones, sin cuestionarios ni respuestas de selección múltiple**.

## Jugar

1. Abre [project.godot](project.godot) con Godot 4.3 o posterior.
2. Pulsa **F5** y elige **Nueva aventura**.
3. Escucha a Byte, camina hacia la terminal iluminada y pulsa **E**.
4. Inspecciona **Esquema**, escribe una consulta y observa la entrada, la consulta construida, las filas y la explicación.
5. Entrega la misión cuando sus evidencias estén completas. La recompensa abre el siguiente destino.

También puedes ejecutar `godot --path .`. No se necesitan plugins, SQLite, cuentas ni conexión a internet.

Jugar en Web: <https://voidxgongy.github.io/sql-quest-from-zero-to-cyber-hero/>.

Para probar la versión web, exporta con el preset **Web** y sirve la carpeta por HTTP (no abras `index.html` con `file://`):

```bash
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server 8080 --directory build/web
```

Abre `http://localhost:8080/`. El preset no usa hilos para evitar requisitos de aislamiento de origen al probar en local.

| Control | Acción |
|---|---|
| WASD / flechas | Movimiento en cuatro direcciones |
| E | Hablar, usar terminal, recoger chip o cruzar puerta |
| E / Espacio | Completar texto y avanzar diálogo |
| Esc | Cerrar laboratorio/panel o abrir pausa |
| J | Diario y objetivo actual |
| Tab | Mapa, destinos y viaje rápido desbloqueado |
| P / I / K | Perfil, inventario y conocimientos |
| Ctrl+Enter | Ejecutar la herramienta actual del laboratorio |

La terminal de una misión se habilita en su destino. Puedes llegar por las puertas laterales o mediante el mapa. Los chips son opcionales. Los errores no restan XP. El instructor acompaña cada prueba: explica errores comunes, recuerda la evidencia pendiente y ofrece tres pistas progresivas. Pedir ayuda no reduce la recompensa.

## La campaña

| Misión | Trabajo práctico | Destino |
|---|---|---|
| Primer día | SELECT y WHERE: obtener solo un registro, con soluciones equivalentes | CyberAcademy |
| Inicio de sesión | Comparar login válido, inválido y error de concatenación | Laboratorio de bases de datos |
| Primera inyección | Demostrar acceso indebido y una contraprueba sin acceso | Simulaciones |
| Datos expuestos | Recuperar información fuera del buscador usando UNION y documentarla | Simulaciones |
| Sistema silencioso | Contrastar hipótesis sobre contenido mediante dos sensores | SOC |
| Reparación | Editar dos consultas y superar pruebas de parametrización y autorización | Laboratorio de bases de datos |
| Práctica profesional | Reproducir, reparar, documentar y actualizar incidentes con UPDATE | Empresa |
| Entrevista | Auditoría integral y registro de certificación mediante INSERT | Oficina de entrevistas |

La casa y la universidad son espacios opcionales de exploración. Al terminar, recibes certificación, contratación y **práctica libre en todas las terminales**.

Se obtienen 10 XP por evidencia nueva, 25 XP por chip y la recompensa de cada misión. Las pistas no reducen XP ni recompensas. Reiniciar el laboratorio no permite repetir XP por evidencias. El perfil conserva insignias, rango profesional e informes.

## Sistemas incluidos

- Ocho interiores conectados con distribución y decoración distintas, colisiones por cuadrícula, cámara suave, puertas, fondos ilustrados ajustados al lienzo, pantallas animadas y partículas. Casa y campus conservan sus murales; las imágenes no definen automáticamente colisiones.
- Personajes pixel art del paquete gráfico: marcha del protagonista en cuatro cuadros con vistas frontal, lateral y trasera; animaciones de NPC; retratos del Profesor Byte, Nova y Zero. El estado de reposo conserva una respiración suave.
- Menú, diálogos progresivos con retrato del hablante, marcos e iconos pixel art, lección inicial de SELECT/WHERE con consulta y resultados demostrativos, diario, mapa con viaje rápido, inventario, perfil, biblioteca y notificaciones.
- Laboratorio con editor SQL, esquema, login, buscador, sensores, edición de consultas de defensa, pruebas de regresión, informes, historial y tres pistas por misión.
- Seis ambientes musicales originales sintetizados localmente, transición por fundido y efectos de pasos, teclado, puertas, error y recompensa.
- Volúmenes independientes; opción de reducir movimiento y mostrar diálogos inmediatamente.
- Guardado automático al ejecutar pruebas, cerrar terminales, entregar misiones, viajar y cada 25 segundos; guardado manual y al salir. Copia de respaldo y recuperación de partidas dañadas.

La interfaz usa un lienzo lógico de 1152×720 con escalado proporcional y bandas cuando cambia la relación de aspecto. Los paneles largos tienen desplazamiento. Las ventanas pequeñas conservan la composición; no hay diseño específico para móvil.

## SQL y precisión educativa

El [intérprete](scripts/sql_simulator/query_engine.gd) tokeniza y evalúa árboles de expresiones. No usa `eval`, comandos del sistema, red ni una base externa. Admite SELECT, WHERE, AND/OR/NOT, comparaciones, LIKE, paréntesis, ORDER BY, LIMIT, UNION/UNION ALL, INSERT, UPDATE y parámetros `?`.

Los datos son inventados y restaurables. Se rechazan sentencias encadenadas, operaciones fuera del subconjunto, columnas desconocidas y tipos incorrectos. Una operación fallida revierte sus cambios. Los parámetros nunca vuelven a tokenizarse como SQL. Una cadena que contiene `OR 1=1` sigue siendo texto si sus comillas no se han cerrado.

**Límites explícitos:** no es un DBMS completo: no hay JOIN, subconsultas, NULL, funciones, DDL ni transacciones SQL. El sensor temporal representa un canal lateral con latencias virtuales, sin ejecutar SLEEP. Las claves visibles simplifican la lección: una aplicación real almacena hashes y verifica contraseñas adecuadamente. El informe se valida por estructura y evidencia capturada; su calidad técnica requiere revisión humana. Las pruebas de reparación verifican un conjunto de casos, no constituyen una demostración formal para todas las entradas.

## Guardado

Godot guarda `sql_quest_v2.json`, su respaldo `.bak` y `settings.cfg` en el directorio `user://` del juego. En Linux normalmente corresponde a `~/.local/share/godot/app_userdata/SQL Quest: From Zero to Cyber Hero/`; en Windows, a `%APPDATA%/Godot/app_userdata/SQL Quest: From Zero to Cyber Hero/`.

Se conserva progreso, datos de laboratorio, evidencias, historial reciente, pistas, consultas de reparación, informes entregados, chips, posición y configuración. Hay un slot; empezar de nuevo pide confirmación. El borrador de un informe todavía no entregado y la consulta actual del editor no se guardan; las consultas ejecutadas sí quedan en el historial.

## Estructura y reutilización

- [scenes/main.tscn](scenes/main.tscn): entrada del juego.
- [scripts/game.gd](scripts/game.gd): coordinación de escenas, menús y navegación.
- [scripts/world/academy.gd](scripts/world/academy.gd) y [scripts/player/hero.gd](scripts/player/hero.gd): mundo y estados del protagonista.
- [scripts/ui/quest_lab.gd](scripts/ui/quest_lab.gd): laboratorio de campaña.
- [scripts/missions/campaign.gd](scripts/missions/campaign.gd): evidencias, evaluación y recompensas.
- [data/missions/campaign.json](data/missions/campaign.json): contenido, herramientas, criterios y objetivos de las misiones.
- [scripts/save_system/save_store.gd](scripts/save_system/save_store.gd) y [scripts/audio/quest_audio.gd](scripts/audio/quest_audio.gd): persistencia y audio.
- [assets/](assets/): paquete importado con spritesheets, retratos, fondos ilustrados, paneles, efectos, manifiesto, atlas de mobiliario y fuente con su licencia. Las colisiones se construyen y prueban aparte de las ilustraciones.
- [tools/make_art.py](tools/make_art.py): fuente reproducible del pixel art SVG; no hace falta Python para jugar.

Se conservó la escena de entrada, se adaptó la navegación con colisiones por cuadrícula y se reutilizó la API del laboratorio anterior. [scripts/sql_simulator.gd](scripts/sql_simulator.gd) es ahora un adaptador del intérprete nuevo. [scripts/sql_lab.gd](scripts/sql_lab.gd) permanece como componente independiente de compatibilidad, cubierto por sus pruebas originales; no participa en la campaña. Se retiraron los cuestionarios, las penalizaciones por errores y los drones que interrumpían el aprendizaje.

## Verificación

En Linux, con Godot y ripgrep disponibles:

```bash
GODOT_BIN=godot tests/run_tests.sh
```

El ejecutor usa un directorio de usuario temporal: no modifica tu partida. Falla si encuentra errores de script aunque Godot devuelva código cero. Para ejecutar cada suite directamente (usa un perfil de pruebas si ya tienes una partida):

```bash
godot --headless --path . --script res://tests/test_campaign.gd
godot --headless --path . --script res://tests/test_sql_simulator.gd
godot --headless --path . --script res://tests/test_sql_lab_ui.gd
godot --headless --path . --script res://tests/test_game_integration.gd
```

Las suites recorren las ocho misiones, variantes SQL, entradas incompletas, regresión de seguridad, persistencia y recuperación, recompensas únicas, colisiones y accesibilidad de terminales/salidas en todos los mapas. La prueba de integración comienza una partida de prueba: por eso se recomienda el ejecutor aislado.

[tests/screenshot_lab.gd](tests/screenshot_lab.gd) renderiza menú, mapa, diálogo, recompensa y laboratorio con Godot real, incluidos 1152×720 y 960×600. Requiere entorno gráfico y también debe ejecutarse con un directorio de usuario de pruebas.

Validación realizada con **Godot 4.3 estable en Linux** y renderizador OpenGL Compatibility. Los recursos no usan APIs exclusivas de Linux, pero **Windows y los ejecutables exportados no se han probado**. Para distribuir binarios se necesitan las plantillas de exportación de Godot; este repositorio entrega el proyecto editable.

Consulta [DISENO_DEL_JUEGO.md](DISENO_DEL_JUEGO.md) para el estado por fases y [GUIA_LABORATORIO_SQL.md](GUIA_LABORATORIO_SQL.md) para ampliar el contenido.
