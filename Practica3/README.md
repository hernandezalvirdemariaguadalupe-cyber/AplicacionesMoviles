<div align="center">

# INSTITUTO POLITÉCNICO NACIONAL
### ESCUELA SUPERIOR DE CÓMPUTO

<br/>

## **Desarrollo de Aplicaciones Móviles Nativas**
### **Práctica 3: Aplicaciones Nativas**

---

**Profesor:** M. en C. Gabriel Hurtado Avilés  
**Grupo:** 7CV4 &nbsp;|&nbsp; **Ciclo Escolar:** 2027-1  
**Semestre:** 2027-1  

---

### **Integrantes del Equipo**

| Nombre Completo | Boleta |
| :--- | :---: |
| **Hernández Alvirde María Guadalupe** | 2022630105 |
| **Aragón Martínez Manuel Alejandro** | [Número de Boleta] |

<br/>

**Ciudad de México, Septiembre de 2026**

---

</div>

<br/>

## 📋 Responsable del equipo utilizado

- **Nombre:** Maria Guadalupe Hernandez Alvirde  
- **Boleta:** 2022630105  
- **Equipo:** DELL Latitude 7480  
- **Procesador:** Intel(R) Core(TM) i7-6600U CPU @ 2.60GHz (2.80 GHz, 2 núcleos, 4 hilos)  
- **RAM:** 16.0 GB (15.9 GB utilizable, 2133 MHz)  
- **Almacenamiento:** 477 GB SSD (203 GB usados, ~274 GB libres)  
- **Gráficos:** Intel(R) HD Graphics 520 (128 MB)  
- **Justificación:** Al analizar las especificaciones de los equipos disponibles, se seleccionó esta laptop debido a que cuenta con 16 GB de memoria RAM, procesador Core i7 con virtualización Intel VT-x activa y más de 270 GB de almacenamiento libre. Esto permite asignar holgadamente 8 GB de RAM al contenedor de macOS y soportar el peso de Xcode y los simuladores sin saturar el sistema operativo anfitrión.

---

## 🗓️ Registro de sesiones de trabajo colaborativo

| # | Fecha | Inicio | Término | Modalidad | Integrantes presentes | Actividades realizadas | Evidencia |
|---|---|---|---|---|---|---|---|
| 1 | 27/09/2026 | 18:00 | 21:00 | Remota (videollamada con pantalla compartida) | Hernandez Alvirde Maria Guadalupe, Aragón Martínez Manuel Alejandro | Comparativa y elección de la PC; clonado de MacOS-Docker; instalación y verificación de WSL 2 con Ubuntu; configuración de `.wslconfig` (virtualización anidada); verificación de aceleración KVM (`kvm-ok`); solución gráfica vía servidor VNC (TigerVNC en puerto 5999 tras falla de renderizado en WSLg); arranque de macOS Recovery, particionado APFS en Disk Utility e inicio de instalación de macOS Ventura. | Capturas 01–17 en carpeta `capturas/` |
| 2 | 28/09/2026 | hh:mm | hh:mm | Remota / Presencial | Hernandez Alvirde Maria Guadalupe, Aragón Martínez Manuel Alejandro | Finalización de instalación de macOS Ventura; configuración inicial del sistema; instalación de Xcode, Homebrew y CocoaPods; ejecución de proyecto Swift de prueba en simulador de iPhone. | Por documentar |
| 3 | 28/09/2026 | hh:mm | hh:mm | Presencial / Remota | Hernandez Alvirde Maria Guadalupe, Aragón Martínez Manuel Alejandro | Desarrollo y pruebas de aplicaciones nativas y multiplataforma (SwiftUI, Flutter, Kotlin Multiplatform). | Por documentar |

---

# Ejercicio 1: Instalación de macOS en la mejor PC del equipo

## 1.1 Identificación y comparativa del equipo

Para determinar qué máquina albergaría el entorno de desarrollo con macOS virtualizado en Docker, se evaluaron las características de hardware de los integrantes:

| Integrante | Procesador | RAM | Almacenamiento | GPU |
|---|---|---|---|---|
| **Maria Guadalupe Hernandez Alvirde** | Intel(R) Core(TM) i7-6600U CPU @ 2.60GHz (2.80 GHz) | 16.0 GB (2133 MHz) | 477 GB SSD (274 GB libres) | Intel(R) HD Graphics 520 (128 MB) |
| **Manuel Alejandro Aragón Martínez** | Intel(R) Core(TM) i5-8265U CPU @ 1.60GHz (hasta 3.90 GHz) | 8.0 GB | 256 GB SSD | Gráficos integrados (Intel UHD Graphics 620) |

**Equipo seleccionado:** Laptop DELL Latitude 7480 de Maria Guadalupe Hernandez Alvirde (Boleta: 2022630105).  

**Justificación técnica de la elección:**
1. **Memoria RAM disponible:** El despliegue de Docker (`docker run`) asigna 8 GB de RAM exclusivamente a la máquina virtual de macOS (`-e RAM=8`), y la configuración de `.wslconfig` reserva hasta 12 GB para WSL 2. En la computadora de Manuel Alejandro (8 GB de RAM en total), esta asignación provocaría un consumo del 100% de la memoria física y un colapso del sistema operativo anfitrión. En cambio, la máquina de Maria Guadalupe (16 GB de RAM) cuenta con margen suficiente para ejecutar Windows, Docker y la máquina virtual simultáneamente.
2. **Capacidad de almacenamiento:** La imagen base de Docker-OSX, el sistema operativo macOS Ventura, el IDE Xcode (~12-15 GB) y los simuladores de iOS requieren decenas de gigabytes libres. La laptop seleccionada cuenta con más de 270 GB de espacio libre en disco sólido frente a los 256 GB totales del equipo secundario.
3. **Aceleración por hardware:** La máquina elegida cuenta con virtualización por hardware (Intel VT-x) activada en firmware, indispensable para habilitar el módulo KVM en Linux y lograr un rendimiento utilizable en el entorno emulado.

### Evidencia de especificaciones del hardware seleccionado
![Información del sistema y especificaciones de la PC](capturas/infopc.png)

---

## 1.3 Instalación del entorno macOS con Docker paso a paso

### Paso 1. Clonar el repositorio oficial
Se clonó el repositorio oficial `MacOS-Docker` desde GitHub dentro del directorio de trabajo de la práctica:

```cmd
cd C:\Users\Lupita Alvirde.Lupita_Alvirde\Practica3
git clone https://github.com/gabrielhuav/MacOS-Docker.git
```

![Clonación del repositorio MacOS-Docker](capturas/clonacion.png)

---

### Paso 2. Instalación y verificación de WSL 2 con Ubuntu
Se verificó la versión instalada de Docker (`Docker version 29.7.2, build a7dcaa6`), se instaló la distribución de Ubuntu sobre el subsistema de Windows para Linux y se comprobó mediante `wsl -l -v` que tanto Ubuntu como `docker-desktop` operan bajo la versión 2 de WSL. Asimismo, se configuró a Ubuntu como la distribución por defecto con `wsl --set-default Ubuntu`.

```cmd
docker --version
wsl -l -v
wsl --set-default Ubuntu
```

![Comandos de preparación y verificación de WSL](capturas/ubuntu.png)
![Listado y confirmación de Ubuntu en WSL versión 2](capturas/wslversion.png)

---

### Paso 3. Integración de Docker Desktop con WSL 2
En la interfaz gráfica de Docker Desktop, se accedió a la sección **Settings > Resources > WSL integration**, donde se activaron las opciones:
- *Enable integration with my default WSL distro*
- Interruptor para habilitar la distro adicional: **Ubuntu**

Durante el proceso se verificaron los registros IPC del backend para confirmar la estabilidad de la comunicación entre Docker Desktop y la distribución Ubuntu.

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



