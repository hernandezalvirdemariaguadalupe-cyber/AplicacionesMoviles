# 4. Arquitectura de MCP

> **Versión de la especificación consultada**: `2026-07-28` (publicada el 28 de julio de
> 2026), la más reciente disponible al momento de esta entrega (21 de septiembre de 2026).
> MCP cambia con frecuencia — de hecho, esta misma versión introdujo cambios importantes
> respecto a revisiones anteriores (ver nota sobre *roots* más abajo) — así que cualquier
> afirmación de este documento debe entenderse referida específicamente a esta versión.

## Modelo host / cliente / servidor

La especificación define tres roles:

- **Host**: el proceso de la aplicación que el usuario tiene abierta. Crea y administra
  clientes, controla permisos, hace cumplir las políticas de seguridad y consentimiento, y
  coordina la integración con el modelo de lenguaje. En nuestra implementación, el host es
  **Visual Studio Code** (con la extensión GitHub Copilot Chat en modo Agent).
- **Cliente**: un componente dentro del host que mantiene una conexión **1 a 1** con un
  servidor específico. El host puede crear varios clientes (uno por cada servidor MCP
  configurado). En nuestro caso, es el cliente MCP interno de Copilot Chat, configurado vía
  [`.vscode/mcp.json`](../.vscode/mcp.json), el que habla directamente con nuestro servidor.
- **Servidor**: un proceso independiente que expone capacidades (herramientas, recursos,
  plantillas de prompt) a través del protocolo. En nuestro caso, es el proceso
  `@modelcontextprotocol/server-filesystem`, lanzado localmente vía `npx` como subproceso
  de VS Code, delimitado a la carpeta `TAREA 1/`.

Un servidor puede ser un proceso local (como el nuestro) o un servicio remoto en internet;
el host puede conectarse a varios servidores a la vez, cada uno aislado del resto (un
servidor no puede "ver" la conversación completa ni las herramientas de otro servidor).

## Primitivas del lado del servidor

Los servidores MCP pueden exponer tres tipos de capacidades ("primitivas"):

- **Tools (herramientas)**: funciones que el *modelo* puede decidir ejecutar (por ejemplo,
  `read_text_file`, `write_file`). Son las que usamos en la Parte 2 de esta actividad.
- **Resources (recursos)**: datos o contenido (archivos, filas de una base de datos,
  resultados de una consulta) que se ponen a disposición del usuario o del modelo como
  contexto, sin que eso implique ejecutar una acción con efectos secundarios.
- **Prompts (plantillas de prompt)**: mensajes o flujos de trabajo preescritos y
  parametrizables que el servidor ofrece para que el usuario los invoque fácilmente (por
  ejemplo, una plantilla "resume este archivo en tres puntos" con un parámetro de ruta).

Es un error común mencionar solo las *tools* y omitir *resources* y *prompts*: los tres son
primitivas igual de válidas del lado del servidor, aunque en la práctica las herramientas
sean las más usadas en clientes orientados a agentes de código.

## Primitivas del lado del cliente

- **Elicitation**: mecanismo por el cual un *servidor* puede pedirle al cliente que
  solicite información adicional al usuario en medio de una operación (por ejemplo, pedir
  confirmación o un dato faltante antes de continuar).
- **Roots**: mecanismo por el cual el *cliente* informa al servidor qué directorios o
  archivos considera relevantes para la sesión de trabajo actual (por ejemplo, la carpeta
  del proyecto abierta). En nuestra propia ejecución del servidor `filesystem`, el log
  mostró exactamente esto: `Updated allowed directories from MCP roots: 1 valid
  directories`, confirmando que VS Code le comunicó al servidor la carpeta `TAREA 1/` como
  único root.

  **Nota sobre esta versión de la especificación**: en la revisión `2026-07-28`, la
  primitiva *roots* fue marcada como **deprecada** (propuesta SEP-2577), con una ventana de
  al menos doce meses antes de poder eliminarse por completo. La especificación aclara
  explícitamente que los *roots* siempre fueron **orientativos, no un mecanismo de control
  de acceso**: el protocolo nunca obligó a los servidores a quedarse dentro de los roots
  declarados. Las nuevas implementaciones deben pasar directorios o archivos como
  parámetros de herramientas, URIs de recursos o configuración del propio servidor. Esto es
  coherente con lo que observamos en la Parte 2: el límite real que impidió leer un archivo
  fuera de `TAREA 1` no vino del mecanismo de *roots*, sino de que el servidor
  `server-filesystem` valida internamente cada ruta contra la carpeta que recibió como
  argumento al arrancar (ver [docs/06-seguridad.md](06-seguridad.md)).

## Transportes

MCP separa el protocolo (los mensajes JSON-RPC y su significado) del transporte (cómo
viajan esos mensajes). La especificación define dos transportes estándar:

- **stdio**: para servidores **locales**. El cliente lanza el servidor como un **proceso
  hijo** y se comunican escribiendo mensajes JSON-RPC delimitados por saltos de línea sobre
  la entrada/salida estándar (`stdin`/`stdout`) de ese proceso. Es el transporte que usamos
  en esta actividad: VS Code lanza `npx ... mcp-server-filesystem` como subproceso.
- **Streamable HTTP**: para servidores **remotos**. Cada mensaje viaja como una petición
  HTTP POST a un único endpoint MCP; las respuestas llegan como un objeto JSON o, si la
  operación lo requiere, como un flujo de eventos (*Server-Sent Events*) asociado a esa
  petición específica.

En ambos casos, la semántica del protocolo (qué significa cada mensaje) es idéntica; solo
cambia cómo se empaquetan y entregan los mensajes.

## Referencias de este documento

- Model Context Protocol. (2026). *Specification (2026-07-28)*.
  https://modelcontextprotocol.io/specification/2026-07-28
- Model Context Protocol. (2026). *Architecture*.
  https://modelcontextprotocol.io/specification/2026-07-28/architecture
- Model Context Protocol. (2026). *Roots (deprecated)*.
  https://modelcontextprotocol.io/specification/2026-07-28/client/roots
- Model Context Protocol. (2026). *Transports*.
  https://modelcontextprotocol.io/specification/2026-07-28/basic/transports
