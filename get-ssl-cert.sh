#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
    echo "Run as root or using sudo"
    exit 1
fi

if [[ "$#" -ne 2 ]]; then
    echo "Este script possui os seguintes parâmetros:"
    echo "1*: domínio"
    echo "2*: e-mail para registro e notificações sobre o domíno"
    echo "*obrigatório"
    echo ""
    echo "Exemplo: sudo bash get-ssl-cert.sh sub.domain.com nome@domain.com"
    exit 1
fi

# certbot
if [[ $(command -v certbot | wc -l) -eq 0 ]]; then
    wget --no-check-certificate -qO- https://git.unirio.br/shell/bash/-/raw/main/install-certbot.sh | sudo bash
fi

# HTTP
WEB_80=$(ss -ltn | grep -c 80)

if [[ "$WEB_80" -gt 0 ]]; then 
    # staging test first
    if certbot certonly -n --staging --dry-run -d "$1" --webroot -w /var/www/letsencrypt --agree-tos -m "$2"; then
        # prod
        certbot certonly -n -d "$1" --webroot -w /var/www/letsencrypt --agree-tos -m "$2"
    else
        echo "Test certificate failed."
    fi
else
    echo "Unable to issue certificate."
    echo "certbot needs to access the server on port 80."
    echo "Check service configuration."
fi