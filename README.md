# Instalación de Odoo 17 en Ubuntu

Este documento proporciona instrucciones detalladas para la instalación de Odoo 17 en servidores Ubuntu. El proceso automatizado mediante script instala el sistema base de Odoo con todas las dependencias necesarias.

## Requisitos del Sistema

- Ubuntu 22.04 LTS (Jammy Jellyfish) o superior
- Acceso root o privilegios sudo
- Mínimo 4GB de RAM (8GB recomendado)
- 20GB de espacio en disco (mínimo)
- Conexión a Internet

## Proceso de Instalación

La instalación se realiza mediante un script bash que automatiza todo el proceso. El script realiza las siguientes acciones:

1. Actualiza el sistema operativo
2. Instala todas las dependencias necesarias
3. Configura PostgreSQL 14
4. Crea un usuario dedicado para Odoo
5. Instala wkhtmltopdf para generación de reportes PDF
6. Clona el repositorio oficial de Odoo 17
7. Configura un entorno virtual Python
8. Instala las dependencias de Python
9. Configura un archivo de parámetros
10. Configura el servicio systemd para Odoo

## Ejecución del Script

1. Guarde el script en un archivo (por ejemplo, `install_odoo17_ubuntu.sh`)
2. Otorgue permisos de ejecución:
   ```bash
   chmod +x install_odoo17_ubuntu.sh
   ```
3. Ejecute el script con privilegios root:
   ```bash
   sudo ./install_odoo17_ubuntu.sh
   ```

## Estructura de Directorios

Después de la instalación, los directorios principales son:

- `/opt/odoo17/odoo` - Código fuente de Odoo
- `/opt/odoo17/odoo-custom-addons` - Directorio para módulos personalizados
- `/opt/odoo17/odoo/odoo-venv` - Entorno virtual Python

## Archivos de Configuración

- Configuración principal: `/etc/odoo17.conf`
- Servicio systemd: `/etc/systemd/system/odoo17.service`

## Gestión del Servicio

### Iniciar Odoo
```bash
sudo systemctl start odoo17
```

### Detener Odoo
```bash
sudo systemctl stop odoo17
```

### Reiniciar Odoo
```bash
sudo systemctl restart odoo17
```

### Verificar estado
```bash
sudo systemctl status odoo17
```

### Ver logs
```bash
sudo journalctl -u odoo17 -f
```

## Acceso a Odoo

Una vez instalado, puede acceder a Odoo desde su navegador:
- URL: `http://[dirección_IP]:8069`
- Base de datos: Debe crear una nueva al primer inicio
- Usuario: `admin`
- Contraseña: Se define al crear la base de datos

## Configuración de Seguridad

Por defecto, el script configura la contraseña maestra de Odoo como `admin_password`. Es altamente recomendable cambiarla:

1. Edite el archivo de configuración:
   ```bash
   sudo nano /etc/odoo17.conf
   ```
2. Modifique la línea `admin_passwd = admin_password` con una contraseña segura

## Configuración Adicional

### Puertos
- XML-RPC (interfaz web): 8069
- Longpolling (para notificaciones): 8072

### Número de Trabajadores
El script configura 2 trabajadores por defecto. Puede ajustar este número según los recursos de su servidor:
- Fórmula recomendada: `(Número de CPU * 2) + 1`
- Edite la línea `workers = 2` en el archivo de configuración

### Configuración de Proxy
Si planea utilizar un proxy inverso como Nginx o Apache, deberá agregar la siguiente línea al archivo de configuración:
```
proxy_mode = True
```

## Solución de Problemas

### Error de Permisos
Si encuentra errores de permisos:
```bash
sudo chown -R odoo17:odoo17 /opt/odoo17
sudo chmod -R 755 /opt/odoo17
```

### Error de PostgreSQL
Si PostgreSQL no se inicia:
```bash
sudo pg_ctlcluster 14 main start
```

### Error de Dependencias Python
Si hay problemas con las dependencias de Python:
```bash
sudo su - odoo17
source /opt/odoo17/odoo/odoo-venv/bin/activate
pip install -r /opt/odoo17/odoo/requirements.txt
exit
```

### Procesos Zombies
Si el servicio no se reinicia correctamente:
```bash
sudo systemctl stop odoo17
sudo pkill -f odoo
sudo systemctl start odoo17
```

### Error de Acceso Web
Si no puede acceder a Odoo desde el navegador:
1. Verifique que el servicio esté en ejecución
2. Compruebe si el firewall está bloqueando el puerto 8069
3. Verifique los logs para más detalles:
   ```bash
   sudo journalctl -u odoo17 -n 50
   ```

## Actualización de Odoo

Para actualizar Odoo a la última versión de la rama 17.0:

```bash
# Detener el servicio
sudo systemctl stop odoo17

# Actualizar el código
sudo su - odoo17
cd /opt/odoo17/odoo
git pull origin 17.0

# Actualizar dependencias
source /opt/odoo17/odoo/odoo-venv/bin/activate
pip install --upgrade -r requirements.txt
exit

# Reiniciar el servicio
sudo systemctl start odoo17
```

## Instalación de Módulos Adicionales

Para instalar módulos personalizados:

1. Coloque los módulos en el directorio `/opt/odoo17/odoo-custom-addons`
2. Asegúrese de que los permisos son correctos:
   ```bash
   sudo chown -R odoo17:odoo17 /opt/odoo17/odoo-custom-addons
   ```
3. Reinicie el servicio:
   ```bash
   sudo systemctl restart odoo17
   ```

## Respaldo y Restauración

### Respaldo de Base de Datos
```bash
sudo su - odoo17
cd /opt/odoo17
/opt/odoo17/odoo/odoo-venv/bin/python3 /opt/odoo17/odoo/odoo-bin -c /etc/odoo17.conf -d [nombre_bd] --backup --stop-after-init
exit
```

### Restauración de Base de Datos
```bash
sudo su - odoo17
cd /opt/odoo17
/opt/odoo17/odoo/odoo-venv/bin/python3 /opt/odoo17/odoo/odoo-bin -c /etc/odoo17.conf -d [nombre_bd_nueva] --restore_file=[archivo_respaldo] --stop-after-init
exit
```

## Notas Importantes

- Este script está optimizado para Ubuntu 22.04 LTS (Jammy Jellyfish)
- La instalación incluye Node.js 18.x para la compilación de assets
- Se han instalado las versiones específicas de greenlet (1.1.2) y gevent (21.8.0) para evitar problemas de compatibilidad con Python 3.10
- El script crea un usuario de PostgreSQL con privilegios de superusuario, lo que es necesario para la creación y restauración de bases de datos

## Configuración de Firewall

Si tiene UFW habilitado, debe permitir el tráfico a los puertos de Odoo:

```bash
sudo ufw allow 8069/tcp
sudo ufw allow 8072/tcp
```

## Configuración Recomendada para Producción

Para entornos de producción, se recomienda:

1. Configurar un proxy inverso (Nginx/Apache)
2. Habilitar SSL/TLS para conexiones seguras
3. Ajustar el número de trabajadores según la carga esperada
4. Implementar respaldos automáticos
5. Monitorizar el rendimiento del sistema

## Soporte

Para problemas relacionados con esta instalación, consulte la documentación oficial de Odoo:
- [Documentación Odoo](https://www.odoo.com/documentation/17.0/)
- [Foro de la comunidad Odoo](https://www.odoo.com/forum/help-1)
