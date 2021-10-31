# -*- mode: Dockerfile -*-

FROM ghcr.io/feelpp/feelpp-toolboxes:latest

USER root
RUN apt-get update;\
        apt-get install -y --no-install-recommends feelpp-mor python3-feelpp-mor; \
        rm -rf /var/lib/apt/lists/* ;

USER feelpp
