#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
    echo "Run as root or using sudo!"
    exit 1
fi

# release check
RELEASES_ARRAY=('bionic' 'focal' 'jammy')
CODENAME=$(lsb_release -cs)
NO_MATCH=true
for release in "${RELEASES_ARRAY[@]}"
do
    if [ "$release" == "$CODENAME" ]; then
        NO_MATCH=false
    fi
done
if $NO_MATCH; then
    echo "Release not supported"
    echo "Supported:"
    echo "${RELEASES_ARRAY[*]}"
    exit 1
fi

NEEDRESTART_CONF=/etc/needrestart/needrestart.conf
if [[ "$CODENAME" == "jammy" ]]; then
    # needrestart auto
    sed -i "s/#\$nrconf{restart} = 'i'/\$nrconf{restart} = 'a'/" $NEEDRESTART_CONF
    # disable kernelhints
    sed -i "s/#\$nrconf{kernelhints}/\$nrconf{kernelhints}/" $NEEDRESTART_CONF
fi

WEB2PY_REPO_URL=https://github.com/web2py/web2py
# help
if [[ "$#" -lt 2 ]] || [[ "$#" -gt 4 ]]; then
    echo ""
    echo "Este script aceita 3 parâmetros:"
    echo "- Primeiro (obrigatório): senha inicial da interface admin do web2py"
    echo "- Segundo (obrigatório): tag da versão do web2py ou latest para a mais recente"
    echo "- Terceiro (opcional): prod ou vagrant"
    echo "- Quarto (opcional): nome do ambiente (branch local e diretório dev)"
    echo ""
    echo "Em produção é necessário verificar se o nginx e o certificado SSL estão instalados e funcionando corretamente."
    echo "Caso não seja informado o terceiro, será criado o certificado autoassinado."
    echo "Se o terceiro for vagrant, serão realizados os procedimentos para viabilizar o bom funcionamento com ele."
    echo "As tags válidas podem ser consultadas em: ${WEB2PY_REPO_URL}/tags"
    echo "UTILIZAR VERSÕES ESPECÍFICAS SOMENTE EM AMBIENTES DEV OU TESTE!"
    echo ""
    echo "Exemplos:"
    echo "Produção (última versão): sudo $0 senha latest prod"
    echo "Dev (versão 2.20.1): sudo $0 senha v2.20.1 vagrant"
    echo "Dev (versão 2.20.4 - candidato): sudo $0 senha v2.20.4 vagrant candidato"
    echo "Teste (última versão): sudo $0 senha latest"
    echo ""
    exit 1
fi

# Set timezone
timedatectl set-timezone America/Sao_Paulo

# Prevent debconf from trying to open stdin
export DEBIAN_FRONTEND=noninteractive

OS_USER=www-data

# limites para o usuario do framework
echo "
${OS_USER}    hard    nofile  10000
${OS_USER}    soft    nofile  4000
${OS_USER}    hard    nproc   4096
${OS_USER}    soft    nproc   1024
"> /etc/security/limits.d/${OS_USER}.conf

# OS Upgrade
apt-get update
apt-get -y upgrade
apt-get autoremove
apt-get autoclean

# install needed software
apt-get -y install \
    git \
    curl \
    ntp \
    build-essential \
    python3-dev \
    libxml2-dev \
    python3-pip \
    unzip \
    libsasl2-dev \
    libldap2-dev \
    libssl-dev

# launchpadlib requisite
pip3 install testresources

pip3 install setuptools --no-binary :all: --upgrade
PIPPATH=$(which pip3)
$PIPPATH install --upgrade uwsgi

if [[ "$3" == 'vagrant' ]]; then
    # webserver
    # curl -fsSLk https://github/install-nginx.sh | sudo bash -s -- web2py80

    # Install and configure Brazilian locale for local postgresql
    locale-gen pt_BR.UTF-8
    dpkg-reconfigure -f noninteractive locales
    update-locale LANG=pt_BR.UTF-8

    # Install postgres on localhost
    apt-get -y install postgresql
    
    # Set password to postgres user
    sudo -u postgres psql -U postgres -d postgres -c "alter user postgres with password 'dev';"
    
    # Enable access through network
    CONFIG_FILE=$(sudo -u postgres psql -t -c "show config_file;")
    sed -i "s/#listen/listen/" $CONFIG_FILE
    sed -i "s/= 'localhost'/= '*'/" $CONFIG_FILE

    HBA_FILE=$(sudo -u postgres psql -t -c "show hba_file;")
    echo "# Custom connections" | sudo tee -a $HBA_FILE
    # IPv4
    echo "host  all all 0.0.0.0/0   md5" | sudo tee -a $HBA_FILE
    # IPv6
    echo "host  all all ::/0        md5" | sudo tee -a $HBA_FILE
    
    # Restart service
    systemctl restart postgresql.service

    # Make vagrant user member of group www-data
    usermod -aG www-data vagrant
    
    # Create symbolic link for better use with vagrant
    if [[ -n "$4" ]]; then
        mkdir -p /vagrant/"$4"
        ln -fs /vagrant/"$4" /home/www-data
    else
        mkdir /vagrant/ambiente
        ln -fs /vagrant/ambiente /home/www-data
    fi
else
    # webserver
    # curl -fsSLk https://github/install-nginx.sh | sudo bash
    
    mkdir /home/www-data    
fi

# Dowload Web2py, set version and admin password
if [[ ! -d /home/www-data/web2py ]]; then
    cd /home/www-data || exit
    
    if [[ "$2" == 'latest' ]]; then
        wget https://github.com/web2py/web2py/raw/refs/heads/master/binaries/web2py_src.zip
        unzip -q web2py_src.zip
    else
        git clone --recursive ${WEB2PY_REPO_URL}.git web2py
        
        cd web2py || exit

        git config --global --add safe.directory '/home/www-data'
        if [[ "$3" == 'vagrant' ]]; then
            git config --global --add safe.directory '/vagrant'
        fi
        
        # validate if tag exists
        if [[ "$(git tag -l "$2" | wc -l)" -eq 1 ]]; then
            WEB2PY_GIT_TAG=$2
        else
            echo ""
            echo "Tag $2 inválida."
            echo "Verifique a lista em ${WEB2PY_REPO_URL}/tags"
            echo ""
            rm -rf /home/www-data
            exit 1
        fi
        
        # change to selected tag
        if [[ -n "$4" ]]; then
            git checkout tags/"$WEB2PY_GIT_TAG" -b "$4"
        else
            git checkout tags/"$WEB2PY_GIT_TAG" -b ambiente-"$WEB2PY_GIT_TAG"
        fi
        
        # update submodules to match selected tag
        if [[ -f .gitmodules ]]; then
            git submodule update
        fi

        cd ..
    fi
    
    cp /home/www-data/web2py/handlers/wsgihandler.py /home/www-data/web2py/
    chown -R www-data:www-data /home/www-data/web2py

    cd /home/www-data/web2py || exit
    # Set web2py initial admin password
    sudo -u www-data python3 -c "from gluon.main import save_password; save_password('$1', 443)"
fi

# Create common nginx sections
mkdir /etc/nginx/conf.d/web2py
echo 'gzip_static on;
gzip_http_version   1.1;
gzip_proxied        expired no-cache no-store private auth;
gzip_disable        "MSIE [1-6]\.";
gzip_vary           on;
' > /etc/nginx/conf.d/web2py/gzip_static.conf

echo 'gzip on;
gzip_disable "msie6";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_buffers 16 8k;
gzip_http_version 1.1;
gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
' > /etc/nginx/conf.d/web2py/gzip.conf

# Create configuration file
if [[ "$3" == 'prod' ]]; then
    FQDN=$(hostname -A | tr -d ' ')

    echo "server {
    listen 443 default_server ssl;
    server_name     ${FQDN};
    ssl_certificate         /etc/letsencrypt/live/${FQDN}/fullchain.pem;
    ssl_certificate_key     /etc/letsencrypt/live/${FQDN}/privkey.pem;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_ciphers ECDHE-RSA-AES256-SHA:DHE-RSA-AES256-SHA:DHE-DSS-AES256-SHA:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    keepalive_timeout    70;
    location / {
        #uwsgi_pass      127.0.0.1:9001;
        uwsgi_pass      unix:///tmp/web2py.socket;
        include         uwsgi_params;
        uwsgi_param     UWSGI_SCHEME \$scheme;
        uwsgi_param     SERVER_SOFTWARE    nginx/\$nginx_version;
        ### remove the comments to turn on if you want gzip compression of your pages
        include /etc/nginx/conf.d/web2py/gzip.conf;
        ### end gzip section
        ### remove the comments if you want to enable uploads (max 50 MB)
        client_max_body_size 50m;
        ###
    }
    ###to enable correct use of response.static_version
    location ~* ^/(\w+)/static(?:/_[\d]+\.[\d]+\.[\d]+)?/(.*)$ {
        alias /home/www-data/web2py/applications/\$1/static/\$2;
        expires max;
        ### if you want to use pre-gzipped static files (recommended)
        ### check scripts/zip_static_files.py and remove the comments
        # include /etc/nginx/conf.d/web2py/gzip_static.conf;
    }
    ###
}" > /etc/nginx/conf.d/web2py.conf
else
    # shellcheck disable=2016,1078
    echo 'server {
    listen 443 default_server ssl;
    server_name     $hostname;
    ssl_certificate         /etc/nginx/ssl/web2py.crt;
    ssl_certificate_key     /etc/nginx/ssl/web2py.key;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_ciphers ECDHE-RSA-AES256-SHA:DHE-RSA-AES256-SHA:DHE-DSS-AES256-SHA:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    keepalive_timeout    70;
    location / {
        #uwsgi_pass      127.0.0.1:9001;
        uwsgi_pass      unix:///tmp/web2py.socket;
        include         uwsgi_params;
        uwsgi_param     UWSGI_SCHEME $scheme;
        uwsgi_param     SERVER_SOFTWARE    nginx/$nginx_version;
        ###remove the comments to turn on if you want gzip compression of your pages
        # include /etc/nginx/conf.d/web2py/gzip.conf;
        ### end gzip section
        ### remove the comments if you want to enable uploads (max 50 MB)
        client_max_body_size 50m;
        ###
    }
    ###to enable correct use of response.static_version
    location ~* ^/(\w+)/static(?:/_[\d]+\.[\d]+\.[\d]+)?/(.*)$ {
        alias /home/www-data/web2py/applications/$1/static/$2;
        expires max;
        ### if you want to use pre-gzipped static files (recommended)
        ### check scripts/zip_static_files.py and remove the comments
        # include /etc/nginx/conf.d/web2py/gzip_static.conf;
    }
    ###
}' > /etc/nginx/conf.d/web2py.conf

    # Generate ssl self-signed certificates
    mkdir /etc/nginx/ssl
    cd /etc/nginx/ssl || exit
    
    if [[ "$CODENAME" == 'bionic' ]]; then
        openssl rand -out "$HOME"/.rnd -hex 256
    fi

    openssl req -x509 -nodes -sha256 -days 365 -newkey rsa:2048 -keyout web2py.key -subj "/C=BR/ST=RJ/L=RJ/O=RJ/OU=RJ/CN=web2pydev.local.br" -out web2py.crt
    openssl x509 -noout -text -in web2py.crt -out web2py.info
fi

# Prepare folders for uwsgi
mkdir /etc/uwsgi
mkdir /var/log/uwsgi

#uWSGI Emperor
if [[ "$CODENAME" == 'focal' ]] || [[ "$CODENAME" == 'jammy' ]]; then
    EXECSTART='uwsgi --master --die-on-term --emperor /etc/uwsgi --logto /var/log/uwsgi/uwsgi.log'
elif [[ "$CODENAME" == 'bionic' ]]; then
    EXECSTART='/usr/local/bin/uwsgi --ini /etc/uwsgi/web2py.ini'
fi

echo "[Unit]
Description = uWSGI Emperor
After = syslog.target

[Service]
ExecStart = ${EXECSTART}
RuntimeDirectory = uwsgi
Restart = always
KillSignal = SIGQUIT
Type = notify
StandardError = syslog
NotifyAccess = all

[Install]
WantedBy = multi-user.target
" > /etc/systemd/system/emperor.uwsgi.service

# Create configuration file /etc/uwsgi/web2py.ini
echo '[uwsgi]

socket = /tmp/web2py.socket
pythonpath = /home/www-data/web2py/
mount = /=wsgihandler:application
processes = 4
master = true
harakiri = 60
reload-mercy = 8
cpu-affinity = 1
stats = /tmp/stats.socket
max-requests = 2000
limit-as = 512
reload-on-as = 256
reload-on-rss = 192
uid = www-data
gid = www-data
touch-reload = /home/www-data/web2py/routes.py
cron = 0 0 -1 -1 -1 python3 /home/www-data/web2py/web2py.py -Q -S welcome -M -R scripts/sessions2trash.py -A -o
no-orphans = true
' > /etc/uwsgi/web2py.ini

systemctl enable emperor.uwsgi.service
systemctl start emperor.uwsgi.service

# set nginx user to www-data
sed -i "s/nginx;/www-data;/" /etc/nginx/nginx.conf

systemctl restart nginx.service