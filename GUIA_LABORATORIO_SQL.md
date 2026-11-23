# Laboratorio SQL — guía de uso y extensión

## Flujo de experimentación

1. Lee el objetivo y la explicación del instructor.
2. Abre Esquema para conocer tablas, columnas y sintaxis disponible.
3. Escribe una consulta o una entrada en la herramienta activa.
4. Ejecuta: se muestran la entrada, la sentencia construida, su resultado y una explicación.
5. Compara un caso distinto. El historial conserva las últimas 60 pruebas de la misión.
6. Reúne las evidencias indicadas; entrega la misión cuando todas estén verificadas.

No hay botones que escriban payloads en la campaña. Las pistas explican el siguiente razonamiento sin proporcionar una consulta completa. Restaurar requiere una segunda pulsación y borra datos de trabajo, historial y evidencias de la misión actual; conserva misiones anteriores, XP y pistas usadas.

## Dialecto

- `SELECT columnas FROM tabla [WHERE condición] [ORDER BY columna ASC|DESC] [LIMIT entero]`
- `SELECT ... UNION [ALL] SELECT ...` con igual número de columnas.
- `INSERT INTO tabla (columnas) VALUES (literales)` con id único positivo.
- `UPDATE tabla SET columna = literal [, ...] WHERE condición`; no modifica id.
- Condiciones con `=`, `!=`, `<>`, `<`, `>`, `<=`, `>=`, `LIKE`, `AND`, `OR`, `NOT` y paréntesis.
- Literales entre comillas simples; `''` representa una comilla dentro del texto. `--` comenta hasta el salto de línea.
- `?` toma valores enlazados por orden, sin interpretarlos como SQL.

Los identificadores no distinguen mayúsculas; los valores de texto sí. AND tiene prioridad sobre OR. LIKE admite `%` y `_`. No hay conversiones implícitas entre números y texto. No se admiten NULL, JOIN, subconsultas, alias, funciones SQL, DDL ni múltiples sentencias. El motor limita entradas a 4096 caracteres, 256 tokens y 24 niveles de paréntesis; las tablas tienen como máximo 100 filas.

El origen de datos es una colección de diccionarios ficticios: estudiantes, usuarios, documentos e incidentes. Los valores enlazados se incorporan como nodos literales del árbol de expresiones. Las operaciones inválidas restauran el estado anterior.

## Evaluación

El evaluador usa los resultados, no la coincidencia textual con una respuesta:

- Registro: devuelve exactamente una fila con los campos del objetivo configurado.
- Login: compara la ejecución concatenada con una ejecución parametrizada de las mismas entradas. Hay bypass si solo la concatenada obtiene acceso. La sesión corresponde a la primera fila, sin convertir automáticamente al usuario en administrador.
- Exposición: comprueba que aparezca información fuera del alcance del buscador.
- Sensores: registra respuestas distintas al investigar contenido sin mostrar las filas. Las condiciones constantes no aportan evidencia del contenido.
- Reparación: ejecuta las consultas editadas con usuarios válidos, claves incorrectas, entradas con SQL y documentos propios/ajenos. Rechazar todo no supera la prueba.
- Informe: requiere evidencia capturada, tres secciones explicadas y longitud mínima. La revisión semántica es humana.
- Incidentes: examina el estado real de las filas después de UPDATE o INSERT.

Las consultas de reparación reciben valores en este orden:

| Aplicación | Parámetros proporcionados por el laboratorio |
|---|---|
| Login | usuario, clave |
| Documentos | id solicitado, id de la sesión autenticada |

El segundo valor de documentos procede de la sesión. La autorización no se resuelve confiando en un identificador de propietario enviado por el cliente. La validación de formatos de entrada es complementaria: no sustituye parámetros ni controles de acceso.

## Añadir una misión

Edita [data/missions/campaign.json](data/missions/campaign.json). Cada objeto contiene:

- `title`, `objective`, `lesson`, `mentor`, `rank`, `badge`, `xp`.
- `room`: índice de uno de los ocho espacios.
- `hints`: tres orientaciones progresivas.
- `tools`: lista de `query`, `login`, `search`, `sensors`, `patch`, `report`.
- `criteria`: evidencias requeridas; `goals` contiene sus etiquetas en el mismo orden.
- `writable`: permite INSERT/UPDATE en el editor.
- `target_record`: campos esperados para un desafío de localización.
- `resolved_ids`: incidentes que deben quedar resueltos.

Criterios reutilizables: `found`, `valid`, `invalid`, `syntax`, `bypass`, `negative`, `leak`, `report`, `bool_yes`, `bool_no`, `time_yes`, `time_no`, `login_fixed`, `access_fixed`, `resolved`, `certificate`.

Los criterios `leak` y `certificate` conservan el escenario Aurora y el estado `certificado`; para otros tipos de evidencia adapta el evaluador de campaña. Mantén las dependencias alcanzables (por ejemplo, un informe exige un bypass o una exposición ya reproducidos). Prueba la nueva misión antes de distribuirla. Cambiar el orden de misiones de una versión publicada requiere una migración del guardado.

## Comprobación docente

El expediente conserva informes y certificaciones. El historial se reinicia al entregar una misión; los informes permanecen. Para evaluar comprensión, pide al estudiante explicar una contraprueba, por qué su consulta parametrizada mantiene la función legítima y por qué la autorización depende de la sesión. El juego no afirma certificar competencias profesionales reales: Aurora Tech y las certificaciones pertenecen a la ficción.

Las soluciones automatizadas están en [tests/test_campaign.gd](tests/test_campaign.gd), separadas de la interfaz de aprendizaje. Sirven para comprobar que cada misión tiene al menos un recorrido válido y que el proyecto sigue funcionando tras cambios.
