# 6. Seguridad

> Estado: pendiente

- [ ] Riesgos: inyección de instrucciones vía contenido de archivo, acceso a rutas fuera del directorio autorizado, escritura/borrado no deseados.
- [ ] Mitigaciones: confirmación humana antes de ejecutar, alcance limitado a un directorio, permisos de solo lectura, revisión de lo que expone el servidor.

## Hallazgo empírico durante la prueba del límite de seguridad (Parte 2)

Al probar el límite de acceso (ver [README.md](../README.md#evidencias)), el primer intento de leer un
archivo fuera de `TAREA 1` **sí tuvo éxito**, no porque el servidor MCP fallara, sino porque el agente de
VS Code eligió una herramienta *integrada de Copilot* (con acceso directo al sistema de archivos, ajena a
MCP) en lugar de la herramienta `read_text_file` del servidor `filesystem`. El panel de log del servidor
MCP no mostró ninguna actividad durante ese intento, confirmando que la petición nunca llegó a él.

Al repetir la prueba restringiendo las herramientas disponibles del chat a únicamente las del servidor MCP
`filesystem` (vía "Chat: Configure Tools" en VS Code), la misma petición sí pasó por `read_text_file` y el
servidor la rechazó correctamente:

```
Access denied - path outside allowed directories:
...\AplicacionesMoviles\Practica1\README.md not in ...\AplicacionesMoviles\TAREA 1
```

**Conclusión**: el límite de "directorio permitido" es una garantía que ofrece **ese servidor MCP en
particular**, aplicada únicamente a las llamadas que efectivamente pasan por sus herramientas. No es una
política global que el cliente o el modelo impongan sobre todas las formas posibles de tocar el disco. Un
agente con acceso a múltiples fuentes de herramientas (MCP + herramientas nativas del editor, por ejemplo)
puede evadir sin querer la restricción de un servidor MCP si usa otra herramienta con mayor alcance para
la misma tarea. Esto es una mitigación práctica a tener en cuenta: si el objetivo es que el *único* acceso
a disco pase por el servidor MCP y su alcance limitado, hay que restringir también las demás herramientas
disponibles para el agente, no basta con configurar bien el servidor MCP.
