# SQL QUEST — Paquete de assets Pixel Art para Godot 4

Este ZIP contiene **3 láminas originales de arte generado** y sus **recortes individuales** organizados por carpetas, incluyendo personajes, retratos, escenarios, elementos del entorno, interfaz y efectos.

## Estructura
- `characters/`: personajes y cuadros de animaciones, para preparar SpriteFrames.
- `portraits/`: retratos del Profesor Byte, Nova, protagonista y rivales.
- `levels/`: escenarios ilustrados de academia, aulas y laboratorios.
- `buildings/`, `environment/`, `props/`, `tilesets/`: decoración, piezas de mapas y mobiliario.
- `ui/`, `effects/`: paneles, iconos y efectos visuales.
- `source_sheets/`: los tres atlas originales por si necesitas otro recorte.
- `manifest.json`: origen y rectángulo de recorte de cada archivo.

## Importar en Godot 4
1. Extrae el ZIP en `res://assets/` dentro del proyecto.
2. En Godot selecciona los PNG, abre la pestaña **Import** y establece filtro **Nearest** (pixel art); después Reimport.
3. Crea `AnimatedSprite2D` para personajes y carga sprites recortados en SpriteFrames. Ajusta manualmente las celdas porque las poses generadas no siempre tienen tamaños uniformes.
4. Usa retratos en `TextureRect`, con `Expand Mode` adecuado y `Stretch Mode = Keep Aspect Centered`.
5. Usa las imágenes de `levels/` como ilustraciones/base visual y **reconstruye sus colisiones y TileMapLayer manualmente**. No son mapas funcionales ni tilesets grid-perfect automáticos.

## Limitación importante
Los recortes pueden conservar parte del fondo original y objetos cercanos porque las láminas artísticas no son atlas con transparencia, separación ni celda exacta garantizada. Son recursos conceptuales/visuales listos para importar como PNG, **no spritesheets de animación automáticamente listos**. Para juego final, limpia fondos y ajusta cuadros de sprites y colisiones en Godot o Aseprite.

## Prompt corto para Codex
"Inspecciona `res://assets/`, lee `manifest.json`, integra los retratos en el sistema de diálogos, usa el arte de las habitaciones como referencia para reconstruir cuatro mapas jugables con colisiones y reemplaza los marcadores de posición del jugador/NPC por animaciones basadas en los recortes disponibles. No supongas que cada recorte es un tileset perfectamente alineado. Mantén el proyecto ejecutable y valida en Godot." 
