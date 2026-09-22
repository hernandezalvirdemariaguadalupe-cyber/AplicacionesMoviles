# Notas de instalación (para reproducir en una máquina limpia)

## Sistema y versiones utilizadas

- Sistema operativo: Windows 11 Pro (10.0.26100)
- Cliente MCP: Visual Studio Code 1.123.0 (con GitHub Copilot Chat, extensión built-in v0.51.0 — trae soporte de Agent Mode / MCP)
- Node.js: v24.14.0
- npm: 11.9.0
- Servidor MCP: `@modelcontextprotocol/server-filesystem` v2026.8.31 (paquete de referencia oficial, ejecutado vía `npx`, sin instalación global)

## Problema encontrado y solución

Al ejecutar `npx -y @modelcontextprotocol/server-filesystem <ruta>` tal cual (sin fijar versión de `zod`),
npm resuelve la última versión de `zod` disponible en ese momento (`4.6.5`), la cual **no incluye las
carpetas compiladas `v3/` y `v4/`** que el SDK de MCP (`@modelcontextprotocol/sdk`) necesita para su capa
de compatibilidad (`zod-compat.js`). Esto provoca el error:

```
Error [ERR_MODULE_NOT_FOUND]: Cannot find module '...\node_modules\zod\v3\index.js'
```

Es un problema del paquete `zod@4.6.5` en npm (versión defectuosa/incompleta), no de MCP ni del servidor
de filesystem. La solución es fijar explícitamente una versión de `zod` compatible y conocida-estable
(`3.25.76`, dentro del rango que el SDK acepta: `^3.25 || ^4.0`) usando múltiples banderas `-p` de `npx`:

```bash
npx -y -p @modelcontextprotocol/server-filesystem -p zod@3.25.76 mcp-server-filesystem "<ruta-permitida>"
```

Esta es exactamente la configuración usada en [`.vscode/mcp.json`](../.vscode/mcp.json) (copia idéntica en
este archivo [`mcp.json`](mcp.json)).

> Si al reproducir esto en otra máquina ya existe una versión estable de `zod` v4 publicada, es posible que
> el comando simple (`npx -y @modelcontextprotocol/server-filesystem <ruta>`) funcione sin este workaround.
> Se documenta aquí porque fue necesario en la fecha de esta entrega (2026-09-21).

## Directorio permitido

El servidor queda delimitado a la carpeta de este repositorio (`TAREA 1/`, resuelta por VS Code como
`${workspaceFolder}`), nunca a la raíz del disco ni a la carpeta de usuario completa.
