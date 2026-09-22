# 7. Casos de uso

## Tres herramientas actuales que implementan MCP

### 1. Visual Studio Code + GitHub Copilot Chat (modo Agent)

Es el cliente que usamos en la Parte 2 de esta actividad. Desde 2025, VS Code incorporó
soporte nativo de MCP en su modo "Agent": el archivo `.vscode/mcp.json` (o la configuración
de usuario) define qué servidores MCP están disponibles, y el modelo detrás del chat
(en nuestro caso, seleccionable entre varios proveedores) puede descubrir e invocar sus
herramientas directamente sobre el proyecto abierto. Lo usamos exactamente para lo que MCP
está pensado: darle a un modelo la capacidad de leer, crear, modificar y buscar archivos
del proyecto sin que la persona copie y pegue contenido manualmente.

### 2. Cursor

Cursor es un editor de código (fork de VS Code) diseñado específicamente para programar
con asistencia de IA. Soporta servidores MCP configurables por proyecto o de forma global,
lo que le permite a su agente conectarse a bases de datos, sistemas de diseño, trackers de
tickets (Linear, Jira) o al propio sistema de archivos del proyecto, y decidir en cada
tarea qué herramienta usar según lo que la persona pida en lenguaje natural.

### 3. Google Antigravity

Antigravity es el entorno de desarrollo agéntico de Google (un IDE orientado a que agentes
de IA trabajen de forma más autónoma sobre un proyecto completo, no solo a completar
código línea por línea). Incluye una "MCP Store" para instalar servidores MCP soportados
por catálogo, y también permite conectar servidores personalizados editando directamente su
archivo `mcp_config.json`, exactamente el mismo patrón cliente-servidor que usamos con VS
Code. Es un ejemplo válido de plataforma que implementa MCP (a diferencia de, por ejemplo,
**Qwen**, que es una *familia de modelos* de Alibaba, no una plataforma de desarrollo: lo
correcto sería referirse a una herramienta concreta que use un modelo Qwen, como Qwen Code,
y no a la familia de modelos en sí).

*(Nota sobre precisión de nombres: por eso en esta sección hablamos de "Google Antigravity"
como entorno de desarrollo agéntico, y no de un modelo o familia de modelos como si fuera
una plataforma.)*

## Cómo editan repositorios completos sin subir archivos manualmente

Antes de MCP, usar un modelo de lenguaje para ayudar con un repositorio implicaba un
proceso manual: la persona abría cada archivo relevante, copiaba su contenido, lo pegaba en
el chat, esperaba la respuesta, y volvía a copiar el resultado de vuelta al archivo. Esto
era lento y limitaba el trabajo a unos pocos archivos pequeños a la vez.

Con un servidor MCP de filesystem (o el equivalente integrado del propio editor) conectado
al proyecto, las tres herramientas anteriores permiten un ciclo distinto, el mismo que
demostramos en la Parte 2 de esta actividad:

1. El agente **lista y explora** la estructura del repositorio por sí mismo
   (`list_directory`, `directory_tree`, búsqueda de archivos), sin que nadie le diga
   manualmente qué archivos existen.
2. **Lee** el contenido de los archivos relevantes bajo demanda (`read_text_file`), solo
   cuando los necesita para la tarea, en vez de que la persona se los pegue por adelantado.
3. **Escribe o edita directamente** en disco (`write_file`, `edit_file`) los cambios que
   decide hacer, aplicando diffs puntuales en vez de que la persona pegue el archivo
   completo de vuelta.
4. Repite este ciclo de lectura/escritura/búsqueda de forma **autónoma y iterativa** hasta
   completar la tarea (por ejemplo, "agrega manejo de errores a todos los endpoints de este
   módulo"), tocando tantos archivos como sea necesario, con el usuario confirmando las
   operaciones sensibles en el camino.

En síntesis, lo que cambia no es que el modelo "sepa más": es que, gracias a MCP (o a
herramientas equivalentes integradas en el editor), el modelo puede **actuar directamente
sobre el repositorio real** en un ciclo de leer-decidir-escribir, en lugar de depender de
que una persona sea el intermediario manual entre el chat y el disco.

## Referencias de este documento

- Google. (2026). *MCP | Google Antigravity Docs*. https://antigravity.google/docs/mcp/
- Microsoft. (2026). *Add and manage MCP servers in VS Code*.
  https://code.visualstudio.com/docs/agent-customization/mcp-servers
- Cursor. (2026). *Model Context Protocol (MCP)*. https://cursor.com/docs/mcp
