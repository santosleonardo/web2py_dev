FROM alpine

COPY get-web2py.sh /get-web2py.sh

RUN chmod +x /get-web2py.sh