FROM debian:latest
MAINTAINER emdentec ltd. <docker@emdentec.com>

RUN apt-get update > /dev/null && \
    apt-get install -y \
        bzip2 \
        curl \
        libmozjs-24-bin \
        python-pip && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/js24 /usr/bin/js && \
    curl -Ls http://github.com/micha/jsawk/raw/master/jsawk > /usr/bin/jsawk && \
    chmod +x /usr/bin/jsawk && \
    pip install b2

COPY ./docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["b2", "backup"]