# Actividad: MCP y el servidor de sistema de archivos

## Datos de identificación

- Nombre completo: María Guadalupe Hernández Alvirde
- Número de boleta: 2022630105
- Grupo: TODO

## Resumen de la actividad

Esta actividad investiga cómo un modelo de lenguaje pasa de estar aislado (solo recibe y
devuelve texto) a poder operar sobre archivos locales, y qué diferencia concretamente al
**Model Context Protocol (MCP)** de consumir una API tradicional. La Parte 1 (`docs/`)
cubre la evolución de los LLM y los modelos con razonamiento, el problema del aislamiento,
la comparación MCP vs. API, la arquitectura del protocolo, el servidor de referencia de
sistema de archivos, los riesgos de seguridad y ejemplos de herramientas actuales que
implementan MCP. La Parte 2 es la implementación real: se instaló y configuró el servidor
MCP `@modelcontextprotocol/server-filesystem` en **VS Code** (con GitHub Copilot Chat en
modo Agent), delimitado a la carpeta de este proyecto, y se documentaron con capturas las
cinco operaciones pedidas (listar, leer, crear, modificar, buscar) más una prueba del
límite de seguridad que reveló un hallazgo relevante no trivial (ver
[Evidencias](#evidencias) y [docs/06-seguridad.md](docs/06-seguridad.md)).

## Índice de la investigación (`docs/`)

1. [Evolución de los modelos](docs/01-evolucion-modelos.md)
2. [El problema del aislamiento](docs/02-problema-aislamiento.md)
3. [MCP frente a una API](docs/03-mcp-vs-api.md)
4. [Arquitectura de MCP](docs/04-arquitectura-mcp.md)
5. [El servidor de sistema de archivos](docs/05-servidor-filesystem.md)
6. [Seguridad](docs/06-seguridad.md)
7. [Casos de uso](docs/07-casos-de-uso.md)

## Tabla comparativa: MCP vs. API

(Detalle y explicación completa en [docs/03-mcp-vs-api.md](docs/03-mcp-vs-api.md))

| Criterio | API tradicional | MCP |
|---|---|---|
| **Quién decide qué se invoca** | La persona desarrolladora, en tiempo de diseño (la llamada al endpoint está escrita de antemano en el código) | El modelo de lenguaje, en tiempo de ejecución, según lo que pida el usuario en lenguaje natural |
| **Cómo se descubren las capacidades** | Leyendo documentación externa (Swagger/OpenAPI, páginas de docs) antes de programar | El servidor publica su propio catálogo de herramientas (nombre + descripción + esquema de parámetros) y el cliente lo consulta en tiempo real |
| **Acoplamiento cliente-servicio** | Alto: el código cliente está escrito a la medida de esa API específica | Bajo: el cliente MCP es genérico y se adapta al catálogo que el servidor exponga |
| **Formato de los mensajes** | Variable según el proveedor (REST+JSON, GraphQL, SOAP, gRPC...) | Estandarizado: siempre JSON-RPC 2.0 |
| **Autenticación y consentimiento** | Vía API key/token gestionado por el desarrollador, sin aprobación del usuario final por llamada | Pensado para pedir consentimiento explícito del usuario antes de ejecutar cada herramienta |
| **Reutilización entre aplicaciones distintas** | Baja: la integración se programa a la medida de cada aplicación | Alta: el mismo servidor MCP puede conectarse sin cambios a distintos clientes (VS Code, Claude Desktop, Cursor, etc.) |

**Importante**: MCP no sustituye a las APIs. Un servidor MCP casi siempre envuelve una API o
un recurso ya existente (el servidor `filesystem` que usamos internamente sigue usando las
llamadas normales del sistema operativo); lo que agrega MCP es una forma estandarizada de
anunciar esas capacidades a un modelo y dejar que decida cuándo usarlas.

## Cliente elegido y justificación

**Visual Studio Code** (v1.123.0), usando la extensión **GitHub Copilot Chat** en modo **Agent**
(viene integrada de fábrica en esta versión de VS Code, no requirió instalación aparte).

Se eligió por tres razones:
- Es un cliente MCP de uso extendido en la industria (no propietario de un solo flujo de trabajo),
  lo que facilita comparar con otros clientes (Claude Desktop, Cursor, etc.) que siguen el mismo protocolo.
- El archivo de configuración (`.vscode/mcp.json`) vive dentro del propio proyecto y es versionable en Git,
  lo que ayuda directamente al requisito de reproducibilidad de esta tarea.
- Permite ver en tiempo real, en el panel "OUTPUT → MCP: filesystem", el ciclo de vida completo de la
  conexión (arranque del proceso, handshake, descubrimiento de herramientas), útil como evidencia.

## Instalación paso a paso (reproducible en máquina limpia)

- Sistema operativo: Windows 11 Pro (10.0.26100)
- Versiones utilizadas: Node.js v24.14.0, npm 11.9.0, VS Code 1.123.0, GitHub Copilot Chat 0.51.0 (built-in),
  `@modelcontextprotocol/server-filesystem` v2026.8.31
- Directorio de trabajo autorizado para el servidor: la carpeta de este proyecto (`TAREA 1/`), resuelta por
  VS Code como `${workspaceFolder}` — nunca la raíz del disco ni la carpeta de usuario completa
- Contenido del archivo de configuración: [`.vscode/mcp.json`](.vscode/mcp.json) (copia idéntica en
  [`config/mcp.json`](config/mcp.json))

Pasos:

1. Instalar [Node.js](https://nodejs.org/) (incluye `npm`/`npx`). Verificar con `node -v` y `npx -v`.
2. Instalar [Visual Studio Code](https://code.visualstudio.com/) 1.99 o superior (trae soporte de MCP).
   Confirmar que la extensión **GitHub Copilot Chat** esté presente (`code --list-extensions` o revisar en
   el panel de extensiones); en versiones recientes viene integrada.
3. Clonar este repositorio y abrir la carpeta `TAREA 1/` en VS Code (`code "TAREA 1"`).
4. VS Code detecta automáticamente `.vscode/mcp.json`. Este define el servidor `filesystem`:
   ```json
   {
     "servers": {
       "filesystem": {
         "type": "stdio",
         "command": "npx",
         "args": [
           "-y",
           "-p", "@modelcontextprotocol/server-filesystem",
           "-p", "zod@3.25.76",
           "mcp-server-filesystem",
           "${workspaceFolder}"
         ]
       }
     }
   }
   ```
   > Nota: se fija `zod@3.25.76` explícitamente porque la última versión de `zod` en npm al momento de esta
   > entrega (4.6.5) está incompleta y rompe la resolución del SDK de MCP. Detalle completo en
   > [config/NOTAS-INSTALACION.md](config/NOTAS-INSTALACION.md).
5. Abrir el panel de Chat (`Ctrl+Alt+I`) y cambiar el modo a **Agent**.
6. Iniciar el servidor: paleta de comandos (`Ctrl+Shift+P`) → **MCP: List Servers** → `filesystem` →
   **Start Server** (o el botón inline "▷ Start" que aparece sobre la definición en `mcp.json`).
7. Verificar en el panel **OUTPUT** (seleccionando "MCP: filesystem" en el desplegable) que aparezca
   `Connection state: Running` y `Discovered 14 tools`. Ver evidencia en
   [img/01-servidor-conectado-14-tools.png](img/01-servidor-conectado-14-tools.png).

## Evidencias

- Servidor detectado y herramientas descubiertas: [img/01-servidor-conectado-14-tools.png](img/01-servidor-conectado-14-tools.png)
- Listar directorio (`list_directory`): prompt *"Lista el contenido del directorio raíz de este proyecto."*
  [img/02a-listar-directorio.png](img/02a-listar-directorio.png) ·
  [img/02b-listar-subdirectorios.png](img/02b-listar-subdirectorios.png) ·
  [img/02c-listar-subdirectorios-cont.png](img/02c-listar-subdirectorios-cont.png)
- Leer archivo existente (`read_text_file`): prompt *"Lee el archivo README.md y dime qué secciones tiene."*
  [img/03-leer-archivo.png](img/03-leer-archivo.png)
- Crear archivo nuevo y escribir contenido (`write_file`): prompt *"Crea un archivo nuevo llamado
  demo-mcp.txt en la raíz del proyecto con este contenido exacto: ..."*
  [img/04-crear-archivo.png](img/04-crear-archivo.png)
- Modificar archivo existente (`edit_file`): prompt *"Al archivo demo-mcp.txt agrégale una segunda línea
  que diga: ..."*
  [img/05-modificar-archivo.png](img/05-modificar-archivo.png)
- Buscar archivo por contenido (`search_files`): prompt *"Busca en este proyecto todos los archivos que
  contengan la palabra 'MCP' en su contenido."*
  [img/06a-buscar-archivo.png](img/06a-buscar-archivo.png) ·
  [img/06b-buscar-archivo-cont.png](img/06b-buscar-archivo-cont.png)
- Prueba del límite de seguridad: [img/07-prueba-limite-seguridad.png](img/07-prueba-limite-seguridad.png)
  — se pidió leer `..\Practica1\README.md` (fuera de `TAREA 1`, la carpeta permitida) usando explícitamente
  la herramienta `read_text_file` del servidor MCP `filesystem`. El servidor respondió:
  ```
  Access denied - path outside allowed directories:
  C:\Users\Lupita Alvirde.Lupita_Alvirde\AplicacionesMoviles\Practica1\README.md not in
  C:\Users\Lupita Alvirde.Lupita_Alvirde\AplicacionesMoviles\TAREA 1
  ```
  El mecanismo que impidió la operación es la validación de rutas contra la lista de `allowed directories`
  que el propio servidor establece al arrancar (y que puede consultarse con su herramienta
  `list_allowed_directories`), no un filtro del modelo ni del cliente.

  **Nota importante descubierta durante la prueba**: el primer intento de esta prueba, antes de restringir
  las herramientas disponibles a solo las del servidor MCP, sí logró leer el archivo fuera del directorio
  permitido — porque el agente usó una herramienta *integrada de Copilot* (con acceso directo al disco, sin
  relación con MCP) en vez de la herramienta del servidor filesystem. El panel OUTPUT del servidor MCP no
  registró ninguna petición en ese intento, confirmando que la operación nunca pasó por él. Esto demuestra
  que el límite de directorios permitidos es una propiedad del **servidor MCP específico**, no una garantía
  general del cliente ni del modelo: si el agente tiene disponible otra herramienta con más alcance, puede
  evadir la restricción sin que MCP tenga forma de impedirlo. Ver también
  [docs/06-seguridad.md](docs/06-seguridad.md).

## Conclusiones personales

TODO

## Referencias (formato APA)

- Anthropic. (2024, 25 de noviembre). *Introducing the Model Context Protocol*.
  https://www.anthropic.com/news/model-context-protocol
- Cursor. (2026). *Model Context Protocol (MCP)*. https://cursor.com/docs/mcp
- Google. (2026). *MCP | Google Antigravity Docs*. https://antigravity.google/docs/mcp/
- Microsoft. (2026). *Add and manage MCP servers in VS Code*.
  https://code.visualstudio.com/docs/agent-customization/mcp-servers
- Model Context Protocol. (2026). *Specification (2026-07-28)* [versión de la
  especificación consultada para esta actividad].
  https://modelcontextprotocol.io/specification/2026-07-28
- Model Context Protocol. (2026). *Architecture*.
  https://modelcontextprotocol.io/specification/2026-07-28/architecture
- Model Context Protocol. (2026). *Roots (deprecated)*.
  https://modelcontextprotocol.io/specification/2026-07-28/client/roots
- Model Context Protocol. (2026). *Transports*.
  https://modelcontextprotocol.io/specification/2026-07-28/basic/transports
- Model Context Protocol. (s. f.). *Servers* [repositorio]. GitHub.
  https://github.com/modelcontextprotocol/servers
- Vaswani, A., Shazeer, N., Parmar, N., Uszkoreit, J., Jones, L., Gomez, A. N., Kaiser, Ł.,
  & Polosukhin, I. (2017). *Attention is all you need*. Advances in Neural Information
  Processing Systems, 30. https://arxiv.org/abs/1706.03762
