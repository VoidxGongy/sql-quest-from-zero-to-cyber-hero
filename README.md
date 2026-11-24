# SQL Quest: CyberGuard · SQL Injection RPG

SQL Quest es un videojuego educativo 2D para Godot 4. El jugador recorre la academia CyberAcademy como auditor de seguridad, recibe misiones del Profesor Byte y entra en laboratorios simulados para demostrar y corregir **SQL Injection**.

El mundo RPG se conserva: hay exploración, colisiones, NPCs, terminales, zonas bloqueadas, diálogos y desbloqueos. El laboratorio aparece como una estación de ciberseguridad dentro de ese mundo, no como la escena principal.

## Objetivo educativo

Al finalizar, el estudiante puede:

- explicar cómo la concatenación mezcla datos de usuario con estructura SQL;
- demostrar un bypass de login con `admin' --` en un entorno aislado;
- reconocer una exposición por `UNION` y una inyección de identificadores en `ORDER BY`;
- interpretar señales indirectas de una SQL Injection ciega;
- reemplazar concatenación por parámetros y aplicar listas blancas;
- comprobar el parche con pruebas legítimas, manipuladas y de autorización;
- redactar un reporte técnico de evidencia, causa y corrección.

## Recorrido de cinco misiones

| Nivel | Incidente | Ataque simulado | Defensa práctica |
|---|---|---|---|
| 1 | Login | `admin' --` anula la comprobación de contraseña | `cursor.execute(..., (?, ?))` |
| 2 | Búsqueda | `UNION` expone datos sintéticos del vault | `LIKE ?` con `%` dentro del valor |
| 3 | `ORDER BY` | `CASE WHEN` altera una estructura dinámica | `ALLOWED_COLUMNS` y valor por defecto |
| 4 | Blind | señales booleanas y latencia virtual | parámetros, autorización y mínimo privilegio |
| 5 | Incidente NullSec | combina login, UNION y ORDER BY | defensa integral, pruebas y reporte final |

Todas siguen el ciclo: briefing de Byte → explicación visual → demostración → experimentación → análisis del impacto → edición del código → regresión → recompensa. No hay niveles obligatorios de SELECT básico, creación de tablas, XSS, comandos o SSTI.

## Ejecución local

Requisito: Godot 4.7.x (o una versión 4.x compatible). No se requieren plugins, servidor, Python ni una base de datos externa.

```bash
godot --path .
```

La entrada del proyecto es `scenes/main.tscn`. En el mundo se usan `WASD` o flechas para caminar y `E` para hablar o usar una terminal. El laboratorio también se cierra con `Esc`.

## Exportación Web

El preset `Web` está en `export_presets.cfg`, usa Compatibility, desactiva hilos y mantiene la simulación dentro de GDScript.

```bash
godot --headless --path . --export-release "Web" build/web/index.html
python3 -m http.server 8080 --directory build/web
```

Abre `http://127.0.0.1:8080/`. No pruebes la exportación con `file://`: el cargador WebAssembly necesita servirse por HTTP. La carpeta `build/web/` debe regenerarse cuando cambie la versión de Godot o el código.

### Publicación estática

- **Netlify:** carga `build/web/` con Deploy manually o configura el comando de exportación anterior y `build/web` como publish directory.
- **Cloudflare Pages:** usa Direct Upload con `build/web/`, o conecta Git con el mismo comando de build y directorio de salida.
- **GitHub Pages:** publica el contenido de `build/web/` en `gh-pages` o como Pages artifact. Conserva `index.html`, `.wasm`, `.pck`, `.js` y los worklets de audio juntos.

No se afirma una URL pública: esta entrega no tiene credenciales de despliegue ni una publicación externa verificada.

## Arquitectura

- `scenes/main.tscn`: escena raíz RPG.
- `scripts/game.gd`: mundo, HUD, diálogos, interacción, transiciones y apertura del laboratorio.
- `scripts/player/hero.gd`: movimiento, orientación e idle/walk con `AnimatedSprite2D` y filtrado nearest.
- `scripts/world/academy.gd`: salas, NPCs, terminales, colisiones y zonas desbloqueables.
- `scripts/missions/campaign.gd`: progresión, puntuación, evidencias, parches y simulaciones de cinco niveles.
- `scripts/ui/quest_lab.gd`: laboratorio responsive de cuatro paneles: ataque, consulta, impacto y arreglo/regresión.
- `scripts/sql_simulator/query_engine.gd`: intérprete acotado en memoria con datos ficticios.
- `data/missions/campaign.json`: contenido educativo de las cinco misiones SQL Injection.
- `tests/`: regresiones del simulador, campaña y flujo RPG.

La carpeta `assets/` contiene los recursos pixel-art existentes. La hoja del protagonista se interpreta con filas verificadas: frente, lateral y espalda; la derecha usa `flip_h` únicamente sobre la fila lateral.

## Programación segura

El código Python mostrado es contenido pedagógico y nunca se ejecuta dentro del navegador. En un sistema real, parametrizar consultas debe acompañarse de autorización, mínimo privilegio, gestión de secretos, logging seguro y hashing de contraseñas. Los identificadores dinámicos no se parametrizan como valores: se seleccionan desde constantes del servidor mediante lista blanca.

El laboratorio es deliberadamente aislado. No ejecuta SQL externo, no inicia procesos, no evalúa Python y no contiene datos reales.

## IA generativa, arte y créditos

Codex se utilizó realmente para inspección, refactorización, diseño de misiones, GDScript, interfaz, animaciones de transición, depuración y pruebas. Se reutilizaron los retratos, sprites y sonidos presentes en el repositorio; no se generaron imágenes nuevas durante esta corrección. Los prompts para generar versiones futuras coherentes están en `PROMPTS_AVATARES.md`.

## Verificación

```bash
GODOT_BIN=godot tests/run_tests.sh
```

La suite actual ejecuta 18 comprobaciones del simulador, 21 de campaña y 26 de integración RPG. La comprobación del parche reconoce patrones educativos, no ejecuta el Python escrito. El detalle, las limitaciones headless y el estado de la exportación Web están en `INFORME_VERIFICACION.md`.

El juego es educativo: ejecuta prácticas únicamente en laboratorios autorizados y sintéticos.
