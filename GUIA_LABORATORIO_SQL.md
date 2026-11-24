# Guía del laboratorio de SQL Injection

CyberGuard no enseña SQL desde cero. Cada actividad usa una consulta mínima solo para mostrar cómo una entrada no confiable altera su estructura y cómo separarla mediante una defensa segura.

## Recorrido de los cinco incidentes

1. **Login:** compara una credencial legítima con `admin' --` y observa cómo el comentario anula la condición de contraseña en el modo vulnerable. Corrige con parámetros `?`.
2. **Búsqueda:** compara un término normal con una entrada `UNION` sintética. Comprueba que el buscador no debe proyectar columnas del `vault`. Corrige usando `LIKE ?` y coloca los comodines en el valor del parámetro.
3. **ORDER BY:** observa por qué una expresión `CASE WHEN` no autorizada modifica el orden. Corrige el identificador con `ALLOWED_COLUMNS`; los nombres de columna no se parametrizan, se validan contra una lista blanca.
4. **Blind SQL Injection:** interpreta cambios booleanos y de latencia simulados sin ver filas. Corrige con parámetros y autorización basada en el propietario de la sesión.
5. **Incidente final:** reúne evidencias, identifica los tres patrones, corrige el código, ejecuta la regresión y redacta un reporte con evidencia, causa y corrección.

## Mecánica común

Cada misión avanza por: introducción → explicación visual → ataque simulado → análisis → edición del parche → tres pruebas de regresión → retroalimentación y recompensa. Los ataques se ejecutan únicamente en el simulador interno de GDScript; no hay base de datos, servidor, Python, shell ni sistema externo.

Las pistas son progresivas y los errores consumen una vida solo al intentar validar un parche inseguro. Reiniciar el escenario permite repetir la demostración sin bloquear la campaña.

## Qué debe comprobar el estudiante

- La entrada normal continúa produciendo el comportamiento legítimo.
- La misma entrada manipulada deja de cambiar la lógica SQL después del parche.
- Los datos sensibles sintéticos no aparecen fuera del alcance autorizado.
- En `ORDER BY`, solo llegan al SQL identificadores constantes elegidos por el servidor.
- En el nivel ciego, ni una respuesta booleana ni una demora simulada permiten inferir datos ajenos.
- El reporte final explica la causa, el impacto y la defensa, sin probar sistemas reales.

Las soluciones mostradas en el juego son contenido pedagógico en Python; nunca se ejecutan como Python. Las contraseñas reales también requieren hashing adecuado y controles de acceso, además de parametrización.
