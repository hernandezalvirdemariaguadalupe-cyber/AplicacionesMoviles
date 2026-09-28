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
| **Aragón Martínez Manuel Alejandro** | 2023630411 |

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

![Configuración de integración WSL en Docker Desktop](capturas/Dockerwsl.png)
![Diagnóstico e integración del servicio Docker Desktop con Ubuntu](capturas/confirmacionubuntudocker.png)

---

### Paso 4. Configurar virtualización anidada (.wslconfig)
Para permitir que la máquina virtual de macOS dentro del contenedor Docker aproveche la virtualización por hardware, se configuró el archivo `.wslconfig` en la raíz del usuario de Windows (`/mnt/c/Users/Lupita Alvirde.Lupita_Alvirde/.wslconfig`) editándolo con `nano` desde Ubuntu con los siguientes parámetros:

```ini
[wsl2]
nestedVirtualization=true
memory=12GB
processors=8
```

Posteriormente se verificó la correcta sintaxis del archivo con `cat` y se aplicaron los cambios reiniciando el servicio con `wsl --shutdown`.

![Edición de archivo .wslconfig mediante nano](capturas/ubuntu2.png)
![Comprobación del contenido guardado en .wslconfig con comando cat](capturas/wslconfig.png)

---

### Paso 5. Verificar aceleración por hardware KVM
Se accedió a la terminal de Ubuntu y se instaló el paquete de diagnóstico de CPU:

```bash
sudo apt update && sudo apt -y install cpu-checker kvm-ok
kvm-ok
```

La salida confirmó la disponibilidad del dispositivo `/dev/kvm`:
```text
INFO: /dev/kvm exists
KVM acceleration can be used
```

![Instalación de paquetes de diagnóstico cpu-checker](capturas/KVM1.png)
![Confirmación de aceleración KVM habilitada (kvm-ok)](capturas/KVM2.png)

---

### Paso 6. Problema con WSLg y solución mediante servidor VNC
Durante las pruebas iniciales con WSLg, la ventana de la máquina virtual no se renderizaba correctamente (únicamente aparecía el ícono minimizado en la barra de tareas pero sin desplegar la interfaz gráfica).  
Para solucionarlo, se modificó el comando de arranque agregando la variable `EXTRA` para desactivar la visualización estándar y levantar un servidor VNC en el puerto 5999 (`-vnc 0.0.0.0:99,password=off`), permitiendo la conexión mediante el cliente **TigerVNC Viewer** en `localhost:5999`.

![Conexión al servidor VNC en localhost:5999 mediante TigerVNC Viewer](capturas/tigervnc2.png)

---

### Paso 7. Ejecutar el contenedor de macOS
Se ejecutó el contenedor con soporte de aceleración KVM, mapeo de puertos SSH (50922:10022) y VNC (5999:5999), asignación de 8 GB de memoria RAM, 4 núcleos de CPU y la versión de sistema macOS Ventura:

```bash
docker run -it --name macos \
  --device /dev/kvm \
  -p 50922:10022 \
  -p 5999:5999 \
  -e GENERATE_UNIQUE=true \
  -e MASTER_PLIST_URL='https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom.plist' \
  -e SHORTNAME=ventura \
  -e RAM=8 -e SMP=8 -e CORES=4 \
  -e EXTRA="-display none -vnc 0.0.0.0:99,password=off" \
  sickcodes/docker-osx:latest
```

![Descarga y ejecución del contenedor sickcodes/docker-osx](capturas/dockerrun.png)

---

### Paso 8. Conexión VNC y arranque de macOS Recovery
Tras levantar el contenedor, se estableció conexión desde TigerVNC Viewer. Se observó el inicio del sistema operativo en modo detallado (*verbose boot*), cargando los módulos del kernel de Apple y servicios del sistema (`com.apple.xpc.launchd`, redes NAT64 y daemon de localización), para dar paso a la pantalla gráfica de arranque con el logotipo de Apple y la barra de progreso.

![Arranque en modo verbose de macOS visualizado en TigerVNC](capturas/tigervnc.png)
![Logs de inicialización y llamadas del sistema en arranque](capturas/arranque.png)
![Pantalla gráfica de arranque con logotipo de Apple cargando](capturas/logoapple.png)

---

### Paso 9. Formatear el disco virtual en Disk Utility
Al entrar al menú de macOS Recovery, se abrió la **Utilidad de Discos (Disk Utility)**. Se seleccionó la opción *"Show All Devices"* para visualizar el disco físico virtual `QEMU HARDDISK Media`, procediendo a borrar y formatear la unidad con los siguientes parámetros:
- **Nombre:** `MacOs`
- **Formato:** `APFS`
- **Esquema:** `GUID Partition Map`

![Utilidad de Discos en macOS Recovery con opción Show All Devices](capturas/MAC3.png)

---

### Paso 10. Proceso de instalación de macOS Ventura
Con el disco formateado y listo, se inició el asistente de instalación de **macOS Ventura**, seleccionando la unidad `MacOs` como disco de destino y comenzando la descarga e instalación de los archivos del sistema base.

![Instalador de macOS Ventura en ejecución mostrando el disco de destino y tiempo estimado](capturas/MAC4.png)
