#!/bin/sh

# web2py
if [ ! -f "${WORK_DIR}/handlers/wsgihandler.py" ]; then
    # custom ini for nginx
    if [ -d /etc/nginx ]; then
        echo "[uwsgi]

socket = /tmp/web2py.socket
pythonpath = ${WORK_DIR}/
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
uid = root
gid = root
touch-reload = ${WORK_DIR}/routes.py
cron = 0 0 -1 -1 -1 python3 ${WORK_DIR}/web2py.py -Q -S welcome -M -R scripts/sessions2trash.py -A -o
no-orphans = true
" > "${WORK_DIR}/uwsgi.ini"
    fi

    # dependencies
    apt-get update
    apt-get install -y --no-install-recommends \
        wget \
        unzip
    rm -rf /var/lib/apt/lists/*
    
    # dir to extract web2py
    # ${variable//search/replace}
    PREV_DIR=$(echo "$WORK_DIR" | sed "s#/web2py##")
    
    # get web2py
    V2_URL=https://mdipierro.pythonanywhere.com/examples/static/2.27.1/web2py_src.zip
    V3_URL=https://github.com/web2py/web2py/raw/refs/heads/master/binaries/web2py_src.zip    
    if [ "$WEB2PY" = "v2" ]; then
        WEB2PY_URL=$V2_URL
    else
        WEB2PY_URL=$V3_URL
    fi

    wget -P /tmp -c "${WEB2PY_URL}"
    unzip -q -o /tmp/web2py_src.zip -d "${PREV_DIR}"
    rm -rf "${WORK_DIR}/applications/examples"
    cp "${WORK_DIR}/handlers/wsgihandler.py" "${WORK_DIR}"

    # admin password
    cd "${WORK_DIR}" || exit
    python -c "from gluon.main import save_password; save_password('$DEPLOY', 443)"

    # IDE settings
    mkdir -p "${WORK_DIR}/.vscode"
    cp /tmp/*.json "${WORK_DIR}/.vscode/"
fi

# permissions
chown -R www-data:www-data "${WORK_DIR}"
# shell and home for www-data
usermod -s /bin/bash -d "${WORK_DIR}/applications" www-data