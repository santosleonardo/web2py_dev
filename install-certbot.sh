#!/bin/bash

if [[ "$EUID" -ne 0 ]]; then
    echo "Run as root or using sudo"
    exit 1
fi

# snap
if [[ $(command -v snap | wc -l) -eq 0 ]]
then
    apt-get update
    apt-get install -y snapd
fi

snap install core
snap refresh core

# certbot
snap install --classic certbot

# dir to check certs
mkdir -p /var/www/letsencrypt

# dir to certs and configs
mkdir -p /etc/letsencrypt

# configs

# options-ssl-nginx
echo '# This file contains important security parameters. If you modify this file
# manually, Certbot will be unable to automatically provide future security
# updates. Instead, Certbot will print and log an error message with a path to
# the up-to-date file that you will need to refer to when manually updating
# this file. Contents are based on https://ssl-config.mozilla.org

ssl_session_cache shared:le_nginx_SSL:10m;
ssl_session_timeout 1440m;
ssl_session_tickets off;

ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;

ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
' > /etc/letsencrypt/options-ssl-nginx.conf

echo '# This file contains important security parameters. If you modify this file
# manually, Certbot will be unable to automatically provide future security
# updates. Instead, Certbot will print and log an error message with a path to
# the up-to-date file that you will need to refer to when manually updating
# this file. Contents are based on https://ssl-config.mozilla.org

SSLEngine on

# Intermediate configuration, tweak to your needs
SSLProtocol             all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite          ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
SSLHonorCipherOrder     off
SSLSessionTickets       off

SSLOptions +StrictRequire

# Add vhost name to log entries:
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"" vhost_combined
LogFormat "%v %h %l %u %t \"%r\" %>s %b" vhost_common
' > /etc/letsencrypt/options-ssl-apache.conf

# ssl-dhparams
echo '-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==
-----END DH PARAMETERS-----
' > /etc/letsencrypt/ssl-dhparams.pem

# acme-challenge-nginx
echo '# This config enables to access /.well-known/acme-challenge/xxxxxxxxxxx
# on all our sites (HTTP), including all subdomains.
# This is required by ACME Challenge (webroot authentication).
# You can check that this location is working by placing ping.txt here:
# /var/www/letsencrypt/.well-known/acme-challenge/ping.txt
# And pointing your browser to:
# http://xxx.domain.tld/.well-known/acme-challenge/ping.txt
#
# Sources:
# https://community.letsencrypt.org/t/howto-easy-cert-generation-and-renewal-with-nginx/3491
#
#############################################################################

# Rule for legitimate ACME Challenge requests (like /.well-known/acme-challenge/xxxxxxxxx)
# We use ^~ here, so that we do not check other regexes (for speed-up). We actually MUST cancel
# other regex checks, because in our other config files have regex rule that denies access to files with dotted names.
location ^~ /.well-known/acme-challenge/ {

    # Set correct content type. According to this:
    # https://community.letsencrypt.org/t/using-the-webroot-domain-verification-method/1445/29
    # Current specification requires "text/plain" or no content header at all.
    # It seems that "text/plain" is a safe option.
    default_type "text/plain";

    # This directory must be the same as in /etc/letsencrypt/cli.ini
    # as "webroot-path" parameter. Also do not forget to set "authenticator" parameter
    # there to "webroot".
    # Do NOT use alias, use root! Target directory is located here:
    # /var/www/common/letsencrypt/.well-known/acme-challenge/
    root /var/www/letsencrypt;
}

# Hide /acme-challenge subdirectory and return 404 on all requests.
# It is somewhat more secure than letting Nginx return 403.
# Ending slash is important!
location = /.well-known/acme-challenge/ {
    return 404;
}
' > /etc/letsencrypt/acme-challenge-nginx.conf

# acme-challenge-apache
echo 'Alias "/.well-known/acme-challenge/" "/var/www/letsencrypt/.well-known/acme-challenge/"

<Directory "/var/www/letsencrypt/.well-known/acme-challenge/">
    Require all granted
    Options Indexes FollowSymLinks
    AllowOverride None
</Directory>
' > /etc/letsencrypt/acme-challenge-apache.conf

# autorenew services
# snap.certbot.renew.service e snap.certbot.renew.timer