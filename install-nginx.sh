#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
    echo "Run as root or using sudo!"
    exit 1
fi

if [[ "$1" == "help" ]]; then
    echo "Optional parameter to config gunicorn or web2py without HTTPS"
    echo ""
    echo "Ex: sudo bash install-nginx.sh gunicorn80"
    echo "Ex: sudo bash install-nginx.sh web2py80"
    exit 1
fi

# ref: https://nginx.org/en/linux_packages.html#Ubuntu

# prereq
apt-get install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring

CODENAME=$(lsb_release -cs)
NEEDRESTART_CONF=/etc/needrestart/needrestart.conf
if [[ "$CODENAME" == "jammy" ]]
then
    # needrestart auto
    sed -i "s/#\$nrconf{restart} = 'i'/\$nrconf{restart} = 'a'/" $NEEDRESTART_CONF
    # disable kernelhints
    sed -i "s/#\$nrconf{kernelhints}/\$nrconf{kernelhints}/" $NEEDRESTART_CONF
fi

# nginx stable

# Import an official nginx signing key so apt could verify the packages authenticity
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

# set up the apt repository for stable nginx packages
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" \
    | sudo tee /etc/apt/sources.list.d/nginx.list

# Set up repository pinning to prefer our packages over distribution-provided ones
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | sudo tee /etc/apt/preferences.d/99nginx

apt-get update

apt-get install -y nginx

# proxy_params
# shellcheck disable=SC2016
if [[ ! -f /etc/nginx/proxy_params ]]
then
    echo 'proxy_set_header Host $http_host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
' > /etc/nginx/proxy_params
fi

if [[ -f "/etc/nginx/conf.d/default.conf" ]]
then
    mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled
fi

if [[ "$1" == "gunicorn80" ]]
then
    echo "server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}
" > /etc/nginx/conf.d/gunicorn-http.conf
elif [[ "$1" == "web2py80" ]]
then
    # shellcheck disable=2016,1078
    echo 'server {
    listen          80;
    server_name     $hostname;
    ###to enable correct use of response.static_version
    location ~* ^/(\w+)/static(?:/_[\d]+\.[\d]+\.[\d]+)?/(.*)$ {
        alias /home/www-data/web2py/applications/$1/static/$2;
        expires max;
        ### if you want to use pre-gzipped static files (recommended)
        ### check scripts/zip_static_files.py and remove the comments
        # include /etc/nginx/conf.d/web2py/gzip_static.conf;
    }
    ###
    ###if you use something like myapp = dict(languages=['en', 'it', 'jp'], default_language='en') in your routes.py
    #location ~* ^/(\w+)/(en|it|jp)/static/(.*)$ {
    #    alias /home/www-data/web2py/applications/$1/;
    #    try_files static/$2/$3 static/$3 =404;
    #}
    ###
    
    location / {
        #uwsgi_pass      127.0.0.1:9001;
        uwsgi_pass      unix:///tmp/web2py.socket;
        include         uwsgi_params;
        uwsgi_param     UWSGI_SCHEME $scheme;
        uwsgi_param     SERVER_SOFTWARE    nginx/$nginx_version;
        ###remove the comments to turn on if you want gzip compression of your pages
        include /etc/nginx/conf.d/web2py/gzip.conf;
        ### end gzip section
        ### remove the comments if you use uploads (max 50 MB)
        client_max_body_size 50m;
        ###
    }
}' > /etc/nginx/conf.d/web2py-http.conf
else
    echo "server {
    listen 80 default_server;
    listen [::]:80 default_server;

    include /etc/letsencrypt/acme-challenge-nginx.conf;

    location / {
        return 301 https://\$host\$request_uri;
    }
}
" > /etc/nginx/conf.d/http.conf
fi

# nginx config
# worker_processes (core count)
PROCESSES=$(grep -c processor /proc/cpuinfo)
sed -i "s/auto/${PROCESSES}/" /etc/nginx/nginx.conf
# worker_connections
CONNECTIONS=$(ulimit -n)
sed -i "/worker_connections/c\    worker_connections  ${CONNECTIONS};" /etc/nginx/nginx.conf

systemctl enable nginx