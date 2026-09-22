# 5. El servidor de sistema de archivos

## "FS" no es parte del protocolo

Es un error conceptual frecuente tratar "el servidor de filesystem" como si fuera parte de
la especificación de MCP. **No lo es**: MCP define el *protocolo* de comunicación (cómo un
cliente descubre e invoca capacidades), pero no define qué capacidades concretas debe
exponer un servidor. El servidor de sistema de archivos (`@modelcontextprotocol/server-
filesystem`) es simplemente **uno de varios servidores de referencia** publicados por el
equipo de MCP (junto con otros como Git, Memory, Fetch, o los que expone cada
comunidad/empresa para sus propios productos: Slack, GitHub, bases de datos, etc.).
Cualquiera puede escribir su propio servidor MCP para exponer cualquier capacidad —incluso
nosotros lo hacemos en [servidor-propio/](../servidor-propio) como parte opcional de esta
actividad—; el de filesystem simplemente resuelve un caso de uso muy común (que un agente
pueda operar sobre archivos locales) y por eso se volvió un ejemplo de referencia estándar.

## Herramientas que expone

En nuestra instalación (ver evidencia en
[img/01-servidor-conectado-14-tools.png](../img/01-servidor-conectado-14-tools.png)), VS
Code detectó **14 herramientas** publicadas por el servidor. Según la documentación del
proyecto (`modelcontextprotocol/servers`, paquete `@modelcontextprotocol/server-
filesystem`), el conjunto de herramientas incluye, entre operaciones de solo lectura y de
escritura:

**Lectura**
- `list_directory` — lista el contenido de un directorio.
- `list_directory_with_sizes` — igual, pero incluyendo el tamaño de cada archivo.
- `directory_tree` — muestra la estructura completa como árbol.
- `read_text_file` / `read_multiple_files` — lee el contenido de uno o varios archivos.
- `read_media_file` — lee archivos binarios (imágenes, etc.).
- `search_files` — busca archivos por nombre o contenido dentro del alcance permitido.
- `get_file_info` — metadatos de un archivo (tamaño, fechas, permisos).
- `list_allowed_directories` — reporta cuáles son los directorios permitidos actuales (la
  usamos directamente en la Parte 2 para verificar el límite de seguridad).

**Escritura**
- `write_file` — crea o sobrescribe un archivo con contenido nuevo.
- `edit_file` — aplica una edición puntual (no reescribe todo el archivo).
- `create_directory` — crea una carpeta.
- `move_file` — mueve o renombra un archivo o carpeta.

(El número exacto de herramientas puede variar ligeramente entre versiones del paquete; lo
importante es la cobertura: listar, leer, escribir, crear, mover y buscar, tal como pide
esta actividad.)

## Cómo se delimita el alcance: directorios permitidos

El servidor recibe, como argumento al arrancar, una o más rutas de directorio que
constituyen su **alcance permitido** (*allowed directories*). En nuestro caso, ese
argumento es `${workspaceFolder}`, que VS Code resuelve a la ruta de `TAREA 1/`:

```json
"args": [
  "-y", "-p", "@modelcontextprotocol/server-filesystem", "-p", "zod@3.25.76",
  "mcp-server-filesystem",
  "${workspaceFolder}"
]
```

Cada vez que se invoca una herramienta con una ruta (por ejemplo, `read_text_file` con
`path: "..\\Practica1\\README.md"`), el servidor primero **resuelve la ruta absoluta** y la
compara contra la lista de directorios permitidos. Si la ruta resultante queda fuera de
todos ellos, el servidor rechaza la operación antes de tocar el disco. Esta validación
ocurre **dentro del propio servidor**, en su propio código — no depende de que el modelo
"decida portarse bien", ni de un permiso del sistema operativo.

## Por qué existe ese límite y qué pasaría sin él

Sin este límite, cualquier herramienta de lectura o escritura del servidor podría operar
sobre **cualquier archivo que el usuario del sistema operativo pueda leer o escribir**: no
solo los archivos del proyecto, sino también documentos personales, credenciales
almacenadas en el perfil del usuario, configuración del sistema, archivos de otras materias
o proyectos, etc. Como el modelo decide qué herramienta invocar con qué argumentos a partir
de una instrucción en lenguaje natural (ver
[docs/03-mcp-vs-api.md](03-mcp-vs-api.md)), un error de interpretación, una instrucción
ambigua del usuario, o —el riesgo más serio— una inyección de instrucciones oculta en el
contenido de un archivo (ver [docs/06-seguridad.md](06-seguridad.md)) podría traducirse en
lecturas o escrituras fuera del proyecto sin que nadie lo autorizara explícitamente.

Delimitar el alcance a una sola carpeta creada específicamente para la tarea (como se pide
en la Parte 2 de esta actividad) reduce el daño posible al peor de los casos: incluso si el
modelo se equivoca o es manipulado, lo máximo que puede tocar son los archivos dentro de
esa carpeta, nunca el resto del disco. Esto es exactamente lo que verificamos de forma
empírica en la prueba del límite de seguridad (ver [README.md](../README.md#evidencias)):
al pedir explícitamente leer un archivo fuera de `TAREA 1` usando la herramienta del
servidor, la respuesta fue `Access denied - path outside allowed directories`.

## Referencias de este documento

- Model Context Protocol. (s. f.). *Servers* [repositorio]. GitHub.
  https://github.com/modelcontextprotocol/servers
- Model Context Protocol. (s. f.). *Filesystem server*.
  https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem
