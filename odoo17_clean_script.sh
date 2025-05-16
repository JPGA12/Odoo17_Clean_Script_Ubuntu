#!/bin/bash

# Script de instalación de Odoo 17 en Ubuntu
# Este script debe ejecutarse con privilegios de root (sudo)

# Colores para mejor visualización
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Iniciando instalación de Odoo 17 ===${NC}"

# Función para verificar si el último comando se ejecutó correctamente
check_status() {
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Error en el paso anterior. Revise los mensajes de error y corrija antes de continuar.${NC}"
        exit 1
    fi
}

# 1. Actualizar el sistema
echo -e "${GREEN}[1/10] Actualizando el sistema...${NC}"
apt update
check_status
apt upgrade -y
check_status

# 2. Instalar dependencias necesarias
echo -e "${GREEN}[2/10] Instalando dependencias...${NC}"
# Primero eliminamos versiones existentes de nodejs y npm
apt remove -y nodejs npm
apt autoremove -y

# Instalamos Node.js desde nodesource
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Instalamos el resto de dependencias
apt install -y postgresql-server-dev-14 build-essential python3-pil \
    python3-lxml python3-dev python3-pip python3-setuptools \
    git gdebi libldap2-dev libsasl2-dev libxml2-dev python3-wheel python3-venv \
    libxslt1-dev libjpeg-dev
check_status

# Instalamos less usando npm
npm install -g less
check_status

# 3. Verificar instalación de PostgreSQL y asegurar que esté funcionando
echo -e "${GREEN}[3/10] Verificando PostgreSQL...${NC}"
psql --version
check_status
systemctl status postgresql
pg_ctlcluster 14 main start

# 4. Crear usuario para Odoo
echo -e "${GREEN}[4/10] Creando usuario para Odoo...${NC}"
if id "odoo17" >/dev/null 2>&1; then
    echo -e "${YELLOW}El usuario odoo17 ya existe, continuando...${NC}"
else
    useradd -m -d /opt/odoo17 -U -r -s /bin/bash odoo17
    check_status
fi

# Asegurarnos que el usuario existe en PostgreSQL
if ! su - postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='odoo17'\"" | grep -q 1; then
    su - postgres -c "psql -c \"CREATE USER odoo17 WITH LOGIN SUPERUSER PASSWORD 'odoo17';\""
    check_status
else
    echo -e "${YELLOW}El usuario odoo17 ya existe en PostgreSQL, actualizando contraseña...${NC}"
    su - postgres -c "psql -c \"ALTER USER odoo17 WITH PASSWORD 'odoo17';\""
    check_status
fi

# 5. Crear directorios necesarios y establecer permisos
echo -e "${GREEN}[5/10] Creando directorios necesarios...${NC}"
mkdir -p /opt/odoo17
mkdir -p /opt/odoo17/odoo-custom-addons
chown -R odoo17:odoo17 /opt/odoo17
chmod -R 755 /opt/odoo17

# 6. Instalar wkhtmltopdf (para reportes PDF)
echo -e "${GREEN}[6/10] Instalando wkhtmltopdf...${NC}"
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
check_status
apt install -y ./wkhtmltox_0.12.6.1-3.jammy_amd64.deb
check_status
rm wkhtmltox_0.12.6.1-3.jammy_amd64.deb

# 7. Clonar repositorio de Odoo e instalar dependencias
echo -e "${GREEN}[7/10] Clonando Odoo 17 desde GitHub...${NC}"
if [ -d "/opt/odoo17/odoo" ]; then
    echo -e "${YELLOW}El directorio /opt/odoo17/odoo ya existe. ¿Desea eliminarlo y volver a clonar? (s/N)${NC}"
    read -r response
    if [[ "$response" =~ ^([sS][iI]|[sS])$ ]]; then
        rm -rf /opt/odoo17/odoo
        su - odoo17 -c "git clone https://www.github.com/odoo/odoo --depth 1 --branch 17.0 /opt/odoo17/odoo"
        check_status
    else
        echo -e "${YELLOW}Continuando con el directorio existente...${NC}"
    fi
else
    su - odoo17 -c "git clone https://www.github.com/odoo/odoo --depth 1 --branch 17.0 /opt/odoo17/odoo"
    check_status
fi

# Crear y configurar entorno virtual
echo -e "${GREEN}[7.1/10] Configurando entorno virtual Python...${NC}"
if [ ! -d "/opt/odoo17/odoo/odoo-venv" ]; then
    su - odoo17 -c "python3 -m venv /opt/odoo17/odoo/odoo-venv"
    
    # Primero actualizamos pip y las herramientas básicas
    su - odoo17 -c "source /opt/odoo17/odoo/odoo-venv/bin/activate && pip install --upgrade pip wheel setuptools"
    
    # Instalamos dependencias de sistema necesarias
    apt install -y python3-dev build-essential
    
    # Instalamos greenlet y gevent específicos para Python 3.10
    su - odoo17 -c "source /opt/odoo17/odoo/odoo-venv/bin/activate && pip install greenlet==1.1.2"
    su - odoo17 -c "source /opt/odoo17/odoo/odoo-venv/bin/activate && pip install gevent==21.8.0"
    
    # Creamos un requirements temporal sin las versiones específicas de gevent y greenlet
    su - odoo17 -c "cat /opt/odoo17/odoo/requirements.txt | grep -v '^gevent' | grep -v '^greenlet' > /opt/odoo17/odoo/requirements_temp.txt"
    
    # Instalamos el resto de dependencias
    su - odoo17 -c "source /opt/odoo17/odoo/odoo-venv/bin/activate && pip install -r /opt/odoo17/odoo/requirements_temp.txt"
    
    # Limpiamos el archivo temporal
    rm -f /opt/odoo17/odoo/requirements_temp.txt
    check_status
else
    echo -e "${YELLOW}El entorno virtual ya existe. Actualizando dependencias...${NC}"
    su - odoo17 -c "source /opt/odoo17/odoo/odoo-venv/bin/activate && pip install --upgrade pip wheel setuptools"
    su - odoo17 -c "source /opt/odoo17/odoo/odoo-venv/bin/activate && pip install greenlet==1.1.2"
    su - odoo17 -c "source /opt/odoo17/odoo/odoo-venv/bin/activate && pip install gevent==21.8.0"
    su - odoo17 -c "cat /opt/odoo17/odoo/requirements.txt | grep -v '^gevent' | grep -v '^greenlet' > /opt/odoo17/odoo/requirements_temp.txt"
    su - odoo17 -c "source /opt/odoo17/odoo/odoo-venv/bin/activate && pip install -r /opt/odoo17/odoo/requirements_temp.txt"
    rm -f /opt/odoo17/odoo/requirements_temp.txt
    check_status
fi

# 8. Configurar archivo de configuración
echo -e "${GREEN}[8/10] Creando archivo de configuración...${NC}"
cat > /etc/odoo17.conf << EOF
[options]
admin_passwd = admin_password
db_host = localhost
db_port = 5432
db_user = odoo17
db_password = odoo17
addons_path = /opt/odoo17/odoo/addons,/opt/odoo17/odoo-custom-addons
xmlrpc_port = 8069
longpolling_port = 8072
workers = 2
EOF

# 9. Configurar servicio systemd
echo -e "${GREEN}[9/10] Configurando servicio systemd...${NC}"
cat > /etc/systemd/system/odoo17.service << EOF
[Unit]
Description=Odoo17
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo17
PermissionsStartOnly=true
User=odoo17
Group=odoo17
ExecStart=/opt/odoo17/odoo/odoo-venv/bin/python3 /opt/odoo17/odoo/odoo-bin -c /etc/odoo17.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

# 10. Iniciar y habilitar el servicio
echo -e "${GREEN}Habilitando e iniciando el servicio Odoo...${NC}"
systemctl daemon-reload
systemctl enable --now odoo17
systemctl status odoo17

# Detener el servicio actual
sudo systemctl stop odoo17

# Matar cualquier proceso de Odoo existente
sudo pkill -f odoo

# Mover el archivo de configuración al lugar correcto
sudo mv /odoo17.conf /etc/odoo17.conf

# Establecer permisos correctos
sudo chown odoo17:odoo17 /etc/odoo17.conf
sudo chmod 640 /etc/odoo17.conf

# Recargar systemd y reiniciar el servicio
sudo systemctl daemon-reload
sudo systemctl restart odoo17

# Verificar el estado
sudo systemctl status odoo17

echo -e "${GREEN}=== Instalación completada ===${NC}"
echo -e "Para ver los logs: ${YELLOW}sudo journalctl -u odoo17${NC}"
echo -e "Acceda a Odoo desde su navegador: ${YELLOW}http://localhost:8069${NC}"
echo -e "IMPORTANTE: Recuerde cambiar 'admin_password' en /etc/odoo17.conf por una contraseña segura"
