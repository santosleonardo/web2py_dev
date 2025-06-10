FROM python:2.7-slim

ENV TZ=America/Sao_Paulo
# setup, entrypoint
ENV WORK_DIR=/opt/web2py
# entrypoint
ENV DEPLOY=dev
ENV WEB2PY=v2

RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

COPY setup-apache-web2py.sh self-signed-ssl.sh prestart.sh entrypoint.sh /usr/local/bin/

WORKDIR $WORK_DIR

RUN setup-apache-web2py.sh

RUN self-signed-ssl.sh

COPY .vscode/ /tmp/

VOLUME $WORK_DIR

EXPOSE 80 443 8000

ENTRYPOINT [ "entrypoint.sh" ]

CMD [ "apache2ctl", "-D", "FOREGROUND" ]