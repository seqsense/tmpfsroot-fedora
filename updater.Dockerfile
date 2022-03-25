# syntax = docker/dockerfile:1.2
ARG FEDORA_MAJOR
FROM fedora:${FEDORA_MAJOR}

RUN --mount=type=cache,target=/var/cache/dnf \
  dnf install -y --repo fedora --repo updates \
    bash \
    dnf-plugins-core \
    findutils \
    make \
  && dnf clean all \
  && rm /etc/yum.repos.d/*.repo \
  && dnf config-manager \
    --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

COPY fedora.repo /etc/yum.repos.d/
RUN sed '/fastestmirror=/d' -i /etc/yum.repos.d/fedora.repo

VOLUME /var/cache/dnf

ARG FEDORA_MAJOR
ENV FEDORA_MAJOR=${FEDORA_MAJOR}

VOLUME /work
WORKDIR /work

COPY updater.sh /
CMD ["/updater.sh"]
