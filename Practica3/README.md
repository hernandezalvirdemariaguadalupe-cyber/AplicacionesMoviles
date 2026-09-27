## Responsable del equipo utilizado

Nombre: Maria Guadalupe Hernandez Alvirde
Boleta: 2022630105
Equipo: DELL Latitude 7480
Procesador: Intel(R) Core(TM) i7-6600U CPU @ 2.60GHz (2.80 GHz)
RAM	(GB)
Almacenamiento: 203 GB de 477 GB usado
Justificación: Al analizar ambos equipos se opto por esta laptop ya que tiene una mejor combinación de RAM, CPU y espacio libre del equipo; soporta virtualización (VT-x/AMD-V habilitada y KVM funcional en WSL)



## Registro de sesiones

| # | Fecha | Inicio | Término | Modalidad | Integrantes presentes | Actividades realizadas | Evidencia |
|---|---|---|---|---|---|---|---|
| 1 | 27/09/2026 | hh:mm | hh:mm | Remota (videollamada con pantalla compartida) | Hernandez Alvirde Maria Guadalupe, Aragón Martínez Manuel Alejandro | Elección de la PC; clonado de MacOS-Docker; instalación de WSL 2 + Ubuntu; configuración de .wslconfig; verificación de KVM; arranque de macOS por VNC (WSLg no mostraba ventanas); formateo del disco e inicio de la instalación de macOS Ventura | Capturas 01–10 |
| 2 | 27/09/2026 | hh:mm | hh:mm | Remota | | Fin de instalación de macOS; instalación de Xcode 15.2, Homebrew y CocoaPods; proyecto de prueba en simulador | |
| 3 | 28/09/2026 | hh:mm | hh:mm | Presencial| | | |

# Ejercicio 1: Instalación de macOS en la mejor PC del equipo

## 1.1 Identificación del equipo

| Integrante | PROCESADPR | RAM | Almacenamiento | GPU |
|---|---|---|---|---|
| Maria Guadalupe Hernandez Alvirde | Intel(R) Core(TM) i7-6600U CPU @ 2.60GHz (2.80 GHz) | 16 GB | 450 GB| 128 MB Intel(R) HD Graphics 520 |
| Nombre 2 | | | | |


**Equipo elegido:** PC de Maria Guadalupe Hernandez Alvirde Boleta: 2022630105.
**Justificación:** Mayor RAM y núcleos del equipo, 200 GB libres y virtualización por hardware habilitada.

![CPU y virtualización habilitada](capturas/01_admin_tareas_cpu.png)
![Memoria RAM](capturas/02_admin_tareas_memoria.png)
![Disco](capturas/03_admin_tareas_disco.png)

## 1.3 Instalación de macOS con Docker

### Paso 1. Clonar el repositorio
Se clonó `github.com/gabrielhuav/MacOS-Docker`.
![Repositorio clonado](capturas/clonacion.png)

### Paso 2. Instalar WSL 2 con Ubuntu
`wsl --install -d Ubuntu` y verificación con `wsl -l -v`.

![WSL con Ubuntu versión 2]()

### Paso 3. Integración de Docker Desktop con WSL
Settings > Resources > WSL Integration > Ubuntu.

![Docker WSL Integration]()

### Paso 4. Configurar virtualización anidada
Archivo `.wslconfig` con `nestedVirtualization=true`, `memory` y `processors`, y reinicio con `wsl --shutdown`.

![Contenido de .wslconfig]()

### Paso 5. Verificar KVM
![kvm-ok: KVM acceleration can be used]()

### Paso 6. Problema con WSLg y solución por VNC
WSLg creaba la ventana (aparecía el ícono en la barra de tareas) pero no la mostraba. Se modificó el arranque para exponer la pantalla por VNC en el puerto 5999 y se usó TigerVNC Viewer.


### Paso 7. Ejecutar el contenedor
Se usó el comando del README, con `--name macos`, `-p 5999:5999` y `-e EXTRA="-display none -vnc 0.0.0.0:99,password=off"`.

![Comando docker run]()

### Paso 8. Conexión por VNC y arranque de macOS Recovery
![Arranque en modo verbose]()
![Logo de Apple cargando]()

### Paso 9. Formatear el disco
Disk Utility > QEMU HARDDISK > Erase: nombre `MacOs`, APFS, GUID Partition Map.

![Disk Utility]()

### Paso 10. Instalar macOS Ventura

![Progreso de instalación]()



