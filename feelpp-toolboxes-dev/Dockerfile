# -*- mode: Dockerfile -*-

FROM ghcr.io/feelpp/feelpp-toolboxes:latest

USER root
RUN apt-get update;\
        apt-get install -y --no-install-recommends 'libfeelpp-toolboxes*-dev';\
        rm -rf /var/lib/apt/lists/* ;

USER feelpp
