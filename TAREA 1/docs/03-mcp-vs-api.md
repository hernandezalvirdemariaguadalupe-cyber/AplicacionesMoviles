# 3. MCP frente a una API (punto obligatorio)

## Qué es una API

Una **API** (*Application Programming Interface*) es un contrato entre programas: quien
desarrolla una aplicación lee la documentación de un servicio (por ejemplo, la API de
Stripe o la de GitHub), decide de antemano **qué endpoint** necesita llamar para lograr
algo (`POST /repos/{owner}/{repo}/issues`), arma la petición con los parámetros exactos que
esa documentación exige, la envía, y escribe código específico para interpretar la
respuesta (parsear el JSON, extraer los campos que le interesan, manejar los posibles
errores). Cada uno de esos pasos —qué endpoint, con qué datos, qué hacer con la
respuesta— está **decidido y escrito de antemano por una persona programadora**, en tiempo
de diseño/desarrollo del software. El programa que consume la API no "decide" en tiempo de
ejecución si llama o no a `POST /issues`; esa decisión ya está fija en el código: se llama
siempre que se cumpla la condición que el desarrollador programó.

## Qué es MCP

El **Model Context Protocol (MCP)** es un protocolo **abierto**, basado en mensajes
**JSON-RPC 2.0**, mediante el cual un programa llamado *servidor* MCP publica un
**catálogo** de capacidades disponibles: **herramientas** (funciones que se pueden
ejecutar), cada una con su **nombre**, su **descripción en lenguaje natural** y el
**esquema** de los parámetros que acepta (típicamente JSON Schema). Un programa llamado
*cliente* (embebido dentro de una aplicación *host*, como un editor de código o un chat de
IA) se conecta a ese servidor y, en tiempo de ejecución, le pregunta: *"¿qué herramientas
tienes disponibles?"*. El servidor responde con la lista completa. A partir de ahí, es el
**modelo de lenguaje** —no una línea de código fija escrita de antemano— quien decide, en
función de lo que la persona usuaria pidió en lenguaje natural, **cuál** de esas
herramientas conviene invocar y **con qué argumentos**, y esa decisión puede cambiar en
cada conversación sin que nadie vuelva a programar nada.

En otras palabras: una API es un contrato que un desarrollador consume de forma predefinida
y estática; MCP es un protocolo de **descubrimiento e invocación dinámica**, donde el
catálogo de capacidades se explora en tiempo real y quien decide qué invocar es el modelo,
no el código previamente escrito.

## Tabla comparativa

| Criterio | API tradicional | MCP |
|---|---|---|
| **Quién decide qué se invoca** | La persona desarrolladora, en tiempo de diseño (la llamada al endpoint está escrita de antemano en el código) | El modelo de lenguaje, en tiempo de ejecución, según lo que pida el usuario en lenguaje natural |
| **Cómo se descubren las capacidades** | Leyendo documentación externa (Swagger/OpenAPI, páginas de docs) antes de programar | El servidor publica su propio catálogo de herramientas (nombre + descripción + esquema de parámetros) y el cliente lo consulta en tiempo real (`tools/list` o equivalente) |
| **Acoplamiento cliente-servicio** | Alto: el código cliente está escrito a la medida de esa API específica; si la API cambia, hay que reescribir código | Bajo: el cliente MCP es genérico (sabe hablar el protocolo), no conoce de antemano qué herramientas existen; se adapta al catálogo que el servidor exponga |
| **Formato de los mensajes** | Variable según el proveedor (REST+JSON, GraphQL, SOAP, gRPC, etc.), cada API define el suyo | Estandarizado: siempre JSON-RPC 2.0, con una estructura de mensajes común a cualquier servidor MCP |
| **Autenticación y consentimiento** | Normalmente vía API key o token, gestionado por el desarrollador, sin que el usuario final autorice cada llamada individual | Pensado para pedir consentimiento explícito del usuario antes de ejecutar una herramienta (el host/cliente debe mostrar qué se va a ejecutar y con qué datos, y el usuario aprueba o rechaza) |
| **Reutilización entre aplicaciones distintas** | Baja: la integración se programa una vez para una aplicación específica; conectar la misma API a otra aplicación implica escribir integración de nuevo | Alta: el mismo servidor MCP (por ejemplo, el de sistema de archivos) puede conectarse sin cambios a Claude Desktop, VS Code, Cursor o cualquier otro cliente que hable el protocolo |

## MCP no sustituye a las APIs

Es un error conceptual común pensar que MCP es una alternativa o un reemplazo de las APIs.
**No lo es.** Un servidor MCP casi siempre es una **capa por encima** de una API, una base
de datos o un recurso ya existente: el servidor `filesystem` que usamos en la Parte 2 de
esta actividad, por ejemplo, internamente sigue usando las llamadas normales del sistema
operativo para leer y escribir archivos (las mismas que usaría cualquier programa escrito
en Node.js); lo único que MCP agrega es una manera estandarizada de **anunciar esas
capacidades a un modelo de lenguaje y dejar que decida cuándo usarlas**. De la misma forma,
un servidor MCP que consulta el clima probablemente llama, por dentro, a una API REST de
clima tradicional. MCP no elimina la necesidad de las APIs subyacentes: las hace
**descubribles y utilizables por un modelo** sin que cada aplicación tenga que programar su
propia integración a mano.
