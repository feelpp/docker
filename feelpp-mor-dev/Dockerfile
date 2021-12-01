# -*- mode: Dockerfile -*-

FROM ghcr.io/feelpp/feelpp-toolboxes-dev:latest

USER root
RUN apt-get update;\
        apt-get install -y --no-install-recommends 'libfeelpp-mor-dev';\
        rm -rf /var/lib/apt/lists/* ;

#USER feelpp
