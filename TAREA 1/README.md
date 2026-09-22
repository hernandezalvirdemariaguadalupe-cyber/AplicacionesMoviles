# Actividad: MCP y el servidor de sistema de archivos

## Datos de identificación

- Nombre completo: TODO
- Número de boleta: TODO
- Grupo: TODO

## Resumen de la actividad

TODO: resumen breve de qué investiga y qué implementa este repositorio.

## Índice de la investigación (`docs/`)

1. [Evolución de los modelos](docs/01-evolucion-modelos.md)
2. [El problema del aislamiento](docs/02-problema-aislamiento.md)
3. [MCP frente a una API](docs/03-mcp-vs-api.md)
4. [Arquitectura de MCP](docs/04-arquitectura-mcp.md)
5. [El servidor de sistema de archivos](docs/05-servidor-filesystem.md)
6. [Seguridad](docs/06-seguridad.md)
7. [Casos de uso](docs/07-casos-de-uso.md)

## Tabla comparativa: MCP vs. API

TODO (ver también [docs/03-mcp-vs-api.md](docs/03-mcp-vs-api.md))

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
- Prueba del límite de seguridad: TODO

## Conclusiones personales

TODO

## Referencias (formato APA)

TODO (incluir la versión de la especificación MCP consultada)
