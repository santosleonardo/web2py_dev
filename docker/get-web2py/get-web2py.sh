#!/bin/sh

if [ -z "$(ls -A /web2py 2>/dev/null)" ]; then
    echo "📁 Pasta /web2py está vazia. Populando conteúdo..."
    wget -P /tmp -c http://web2py.com/examples/static/web2py_src.zip
    unzip -q -o /tmp/web2py_src.zip -d /opt
    rm -rf /opt/web2py/applications/examples
    cp /opt/web2py/handlers/wsgihandler.py /opt/web2py/
else
    echo "✅ Pasta /web2py já contém conteúdo. Pulando inicialização."
fi