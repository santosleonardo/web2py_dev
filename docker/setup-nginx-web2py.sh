#!/bin/bash

# common nginx sections
if [ ! -d /etc/nginx/conf.d/web2by ]; then
    mkdir -p /etc/nginx/conf.d/web2py

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
fi

# nginx web2py.conf
# shellcheck disable=2016,1078
if [ ! -f /etc/nginx/conf.d/web2py-self.conf ]; then
    echo "server {
    listen 443 default_server ssl;
    server_name     \$hostname;
    ssl_certificate         /etc/nginx/ssl/web2py.crt;
    ssl_certificate_key     /etc/nginx/ssl/web2py.key;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    keepalive_timeout    70;
    
    location / {
        uwsgi_pass      unix:///tmp/web2py.socket;
        include         uwsgi_params;
        uwsgi_param     UWSGI_SCHEME \$scheme;
        uwsgi_param     SERVER_SOFTWARE    nginx/\$nginx_version;
        ###remove the comments to turn on if you want gzip compression of your pages
        # include /etc/nginx/conf.d/web2py/gzip.conf;
        ### end gzip section
        ### remove the comments if you want to enable uploads (max 50 MB)
        # client_max_body_size 50m;
        ###
    }
    
    ###to enable correct use of response.static_version
    location ~* ^/(\w+)/static(?:/_[\d]+\.[\d]+\.[\d]+)?/(.*)$ {
        alias ${WORK_DIR}/applications/\$1/static/\$2;
        expires max;
        ### if you want to use pre-gzipped static files (recommended)
        ### check scripts/zip_static_files.py and remove the comments
        # include /etc/nginx/conf.d/web2py/gzip_static.conf;
    }
    ###
}" > /etc/nginx/conf.d/web2py-self.conf
fi