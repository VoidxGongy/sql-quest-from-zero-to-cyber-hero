# SQL Quest — diseño y estado de implementación

## Intención

Un estudiante pasa de su primera consulta a una evaluación laboral práctica. El bucle es explorar → conversar → experimentar → observar evidencia → corregir → probar → documentar → recibir una certificación. El error forma parte del aprendizaje y no quita experiencia.

La dirección visual conserva azul oscuro, verde, morado y pixel art del proyecto original. Los personajes y objetos usan atlas SVG compuestos por píxeles, con filtrado nearest en el mundo. La consola usa una fuente monoespaciada incluida con licencia. La interfaz se mantiene separada del mundo, con textos legibles, foco de teclado y paneles desplazables.

## Fases implementadas

| Fase | Resultado | Comprobación |
|---|---|---|
| 1 · Base jugable | Menú, personaje con estados, 8 espacios, cámara, colisiones, NPC, diálogo, música y guardado | Integración: spawn, obstáculos, interacción, continuidad de partida |
| 2 · SQL | Lexer, expresiones, lecturas y escrituras limitadas, parámetros, historial y feedback | Casos de sintaxis, precedencia, tipos, UNION, rollback y entradas incompletas |
| 3 · Primera misión | Localización de un registro por SQL escrito por el jugador; variantes equivalentes | Consulta alternativa, entrega por señal, XP y siguiente ubicación |
| 4 · Progresión | Rangos, XP, insignias, chips, diario, perfil, mapa y pistas | Recompensas únicas, reinicio sin duplicar XP, persistencia de evidencia |
| 5 · Avanzado | Login, booleanas, UNION, dos sensores ciegos, reparaciones, práctica e entrevista | Recorrido automatizado de las 8 misiones y casos válidos/adversarios |
| 6 · Pulido | Atlas originales, estados visuales, ambientes musicales, fundidos, preferencias y ceremonia | Importación y ejecución en Godot 4.3; capturas reales a dos resoluciones |

## Espacios

Casa y universidad introducen la exploración con mobiliario doméstico y biblioteca. CyberAcademy es un aula de prácticas. El laboratorio de datos tiene pasillos de servidores. Simulaciones contiene estaciones de investigación. La empresa usa puestos de trabajo. El SOC reúne monitores y servidores. La entrevista termina ante Alex, con una certificación animada.

Los ocho interiores comparten tamaño y biblioteca de tiles; su decoración y distribución varían. Son mapas compactos de una primera campaña, no una ciudad extensa. Las puertas enlazan espacios consecutivos y el mapa permite viajar a destinos ya desbloqueados. Los chips contienen notas de aprendizaje y recompensas opcionales.

## Personajes y estados

- Protagonista: reposo, caminar en cuatro direcciones, trabajo en terminal, error, celebración, certificación y entrevista.
- Byte: exigente con la evidencia, paciente con el error.
- Nova: propone observar y comparar antes de sacar conclusiones.
- Zero: supervisa el alcance autorizado y los sensores.
- Kernel: exige una entrega profesional comprobable.
- Alex: evalúa investigación, reparación y regresión antes de contratar.

Los NPC tienen sprites propios y animación sencilla de reposo/conversación. Las escenas de entrevista y graduación son breves y usan el mismo sistema de diálogo y sprites; no hay cinemáticas ilustradas ni voces.

## Recompensas

Diez XP por evidencia nueva y veinticinco por chip. La entrega de cada misión otorga su recompensa configurada; pedir pistas no reduce XP ni recompensas. Una lista persistente de evidencias premiadas impide cultivar XP reiniciando el laboratorio. Cada 250 XP aumenta el nivel; los certificados actualizan el rango profesional y el perfil.

La contratación abre práctica libre. Las consultas y reparaciones se pueden seguir ensayando sin reabrir misiones ni duplicar recompensas.

## Arquitectura

La escena de entrada instancia el mundo, el jugador, la interfaz y el audio. El coordinador comunica eventos por señales; no contiene el parser SQL. El intérprete no conoce la interfaz. La campaña evalúa resultados y emite los cambios de progreso. El almacenamiento serializa valores JSON versionados, valida estructuras y usa archivo temporal con respaldo. Las preferencias se guardan por separado.

Las herramientas, objetivos y criterios de cada misión se definen en [campaign.json](data/missions/campaign.json). Se puede añadir contenido usando los evaluadores existentes; una mecánica educativa completamente nueva necesita un nuevo evaluador, no cambios en el intérprete SQL. El laboratorio muestra las herramientas asignadas en los datos.

## Límites de esta entrega

- SQL es un dialecto educativo acotado, no SQLite ni un DBMS completo.
- El ejercicio temporal es un sensor virtual, no una implementación de funciones de retardo de un DBMS.
- La validación del informe comprueba secciones y evidencia; no comprende ni califica semánticamente la prosa.
- Las baterías de reparación son pruebas de comportamiento con casos conocidos; no prueban formalmente toda posible consulta.
- Los mapas, el pixel art y las ceremonias son compactos; no incluyen una campaña narrativa extensa, voces ni animación artística cuadro a cuadro para cada NPC.
- Hay un guardado local y controles de teclado/ratón. No hay mando, sincronización, múltiples perfiles ni integración con bases externas.
- Se verificó Linux; faltan prueba física en Windows, exportación de ejecutables y evaluación con estudiantes de la duración/dificultad.

Estos límites no bloquean el recorrido jugable completo de las ocho misiones.
