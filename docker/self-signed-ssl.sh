#!/bin/bash

if [[ -d /etc/apache2 ]]; then
    SSL_DIR=/etc/apache2/ssl
elif [[ -d /etc/nginx ]]; then
    SSL_DIR=/etc/nginx/ssl
fi

# ssl self-signed certificates
if [[ ! -d "$SSL_DIR" ]]; then
    mkdir -p "$SSL_DIR"
    cd "$SSL_DIR" || exit

    openssl req -x509 -nodes -sha256 -days 365 -newkey rsa:2048 -keyout web2py.key -subj "/C=BR/ST=RJ/L=RJ/O=RJ/OU=RJ/CN=web2pydev.local.br" -out web2py.crt
    openssl x509 -noout -text -in web2py.crt -out web2py.info
fi