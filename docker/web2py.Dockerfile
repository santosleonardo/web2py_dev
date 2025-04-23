FROM tiangolo/uwsgi-nginx:python3.10

# timezone
ENV TZ=America/Sao_Paulo

# Custom app directory
ENV UWSGI_INI=/opt/web2py/uwsgi.ini

# install needed software
RUN apt update && \
    apt install -y unzip wget
 
# uwsgi logs 
RUN mkdir -p /var/log/uwsgi
 
# Generate ssl self-signed certificates
RUN mkdir /etc/nginx/ssl && \
    cd /etc/nginx/ssl && \
    openssl req -x509 -nodes -sha256 -days 365 -newkey rsa:2048 -keyout web2py.key -subj "/C=BR/ST=RJ/L=RJ/O=RJ/OU=RJ/CN=web2pydev.local.br" -out web2py.crt && \
    openssl x509 -noout -text -in web2py.crt -out web2py.info

WORKDIR /opt/web2py

# uwsg.ini
COPY uwsgi.ini .

# nginx config
COPY web2py.conf /etc/nginx/conf.d

COPY requirements.txt .

RUN pip3 install -r requirements.txt

# get web2py
RUN wget -P /tmp -c https://github.com/web2py/web2py/raw/refs/heads/master/binaries/web2py_src.zip && \
    unzip -q -o /tmp/web2py_src.zip -d /opt && \
    rm -f /tmp/web2py_src.zip && \
    rm -rf /opt/web2py/applications/examples && \
    cp /opt/web2py/handlers/wsgihandler.py /opt/web2py/

# admin password
RUN python3 -c "from gluon.main import save_password; save_password('dev', 443)"

# vscode debug conf
COPY launch.json .
RUN mkdir -p /opt/web2py/.vscode && \
    mv launch.json /opt/web2py/.vscode