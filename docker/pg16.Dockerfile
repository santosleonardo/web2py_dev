FROM postgres:16

RUN sed -i 's/# pt_BR.U/pt_BR.U/' /etc/locale.gen && \
    locale-gen pt_BR.UTF-8 && \
    dpkg-reconfigure -f noninteractive locales