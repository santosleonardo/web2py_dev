FROM tiangolo/uwsgi-nginx:python3.10

ENV TZ=America/Sao_Paulo

# setup, entrypoint
ENV WORK_DIR=/opt/web2py
# entrypoint
ENV DEPLOY=dev
ENV WEB2PY=v3

ENV UWSGI_INI=$WORK_DIR/uwsgi.ini

COPY setup-nginx-web2py.sh self-signed-ssl.sh /usr/local/bin/

WORKDIR $WORK_DIR

RUN setup-nginx-web2py.sh

RUN self-signed-ssl.sh

COPY .vscode/ /tmp/

COPY prestart.sh /app/

VOLUME $WORK_DIR

EXPOSE 80 443 8000