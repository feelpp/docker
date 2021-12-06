# -*- mode: Dockerfile -*-

ARG TAG
FROM ghcr.io/feelpp/feelpp:$TAG

USER root
RUN apt-get update;\
        apt-get install -y --no-install-recommends feelpp-toolboxes feelpp-toolboxes-data; \
        apt-get install -y --no-install-recommends 'python3-feelpp-toolboxes*';\
        rm -rf /var/lib/apt/lists/* ;

USER feelpp
