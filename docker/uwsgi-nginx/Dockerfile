FROM tiangolo/uwsgi-nginx:python3.10

ENV TZ=America/Sao_Paulo

ENV UWSGI_INI=/opt/web2py/uwsgi.ini

# install needed software
RUN apt update && \
 apt install -y unzip wget

# uwsgi logs 
RUN mkdir -p /var/log/uwsgi

# uwsg.ini
COPY uwsgi.ini /opt/web2py/

# nginx config
COPY nginx.conf /opt/web2py/

WORKDIR /opt/web2py

COPY requirements.txt .

RUN pip3 install -r requirements.txt

# get web2py
# RUN wget -P /tmp -c http://web2py.com/examples/static/web2py_src.zip && \
#  unzip -q -o /tmp/web2py_src.zip -d /opt && \
#  rm -f /tmp/web2py_src.zip && \
#  rm -rf /opt/web2py/applications/examples && \
#  cp /opt/web2py/handlers/wsgihandler.py /opt/web2py/