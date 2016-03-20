FROM jenkins:1.642.2
MAINTAINER emdentec ltd. <docker@emdentec.com>

USER root

RUN apt-get update && \
    apt-get install -y \
        lxc \
        sudo && \
    rm -rf /var/lib/apt/lists/*

ENV SUDOER_FILE="/etc/sudoers.d/jenkins"
RUN echo "jenkins    ALL=(ALL)   NOPASSWD: ALL" >> ${SUDOER_FILE} && chmod 0440 ${SUDOER_FILE}

USER jenkins

COPY ./docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]