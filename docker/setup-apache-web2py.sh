#!/bin/bash

apt-get update
apt-get install -y --no-install-recommends \
  apache2 \
  libapache2-mod-wsgi
rm -rf /var/lib/apt/lists/*

# apache modules
a2enmod ssl proxy proxy_http wsgi expires headers

# apache
echo "
WSGIDaemonProcess web2py user=www-data group=www-data display-name=%{GROUP}

<VirtualHost *:80>
  ServerName localhost
  Redirect / https://localhost/
</VirtualHost>

<VirtualHost _default_:443>
  ServerName localhost
  
  SSLEngine on
  SSLCertificateFile /etc/apache2/ssl/web2py.crt
  SSLCertificateKeyFile /etc/apache2/ssl/web2py.key
  
  WSGIProcessGroup web2py
  WSGIScriptAlias / ${WORK_DIR}/wsgihandler.py
  WSGIPassAuthorization On

  <Directory ${WORK_DIR}>
    AllowOverride None
    Require all denied
    <Files wsgihandler.py>
      Require all granted
    </Files>
  </Directory>

  AliasMatch ^/([^/]+)/static/(?:_[\d]+.[\d]+.[\d]+/)?(.*) \\
        ${WORK_DIR}/applications/\$1/static/\$2

  <Directory ${WORK_DIR}/applications/*/static/>
    Options -Indexes
    ExpiresActive On
    ExpiresDefault \"access plus 1 hour\"
    Require all granted
  </Directory>

  CustomLog /var/log/apache2/ssl-access.log common
  ErrorLog /var/log/apache2/error.log
</VirtualHost>
" > /etc/apache2/sites-available/000-default.conf


# forward logs to Docker's log collector
ln -sf /dev/stdout /var/log/apache2/ssl-access.log
ln -sf /dev/stderr /var/log/apache2/error.log