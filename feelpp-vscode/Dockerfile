# -*- mode: Dockerfile -*-

# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.145.1/containers/ubuntu/.devcontainer/base.Dockerfile

# [Choice] Ubuntu version: bionic, focal
ARG VARIANT="focal"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

USER root
ARG CHANNEL
ENV CHANNEL=${CHANNEL:-latest}
RUN apt-get update \
        && apt-get install -y \
        vim \
        ssh \
        sudo \
        wget gpg \
        software-properties-common ;\
        rm -rf /var/lib/apt/lists/*

ENV DEBIAN_FRONTEND=noninteractive        
RUN echo "deb http://archive.ubuntu.com/ubuntu focal-proposed main restricted" |  tee -a /etc/apt/sources.list; \ 
        echo "deb http://archive.ubuntu.com/ubuntu focal-proposed universe" |  tee -a /etc/apt/sources.list; \
        echo "deb http://archive.ubuntu.com/ubuntu focal-proposed multiverse" |  tee -a /etc/apt/sources.list; \
        apt-get -qq update; \
        apt-get -y install tzdata dos2unix

RUN wget -qO - http://apt.feelpp.org/apt.gpg | gpg --dearmor > feelpp.gpg; \
        install -o root -g root -m 644 feelpp.gpg /etc/apt/trusted.gpg.d; \
        echo "deb [signed-by=/etc/apt/trusted.gpg.d/feelpp.gpg] http://apt.feelpp.org/ubuntu focal ${CHANNEL}" | tee -a /etc/apt/sources.list.d/feelpp.list; \
        rm -f feelpp.gpg; \
        apt-get update ;\
        apt-get install -y --no-install-recommends g++ clang-9 man-db libboost-regex1.67.0-icu66 feelpp-quickstart feelpp-data feelpp-tools python3-feelpp make rsync; \
        rm -rf /var/lib/apt/lists/* ;

RUN     echo "export FEELPP_REPOSITORY=/feel" >> ~feelpp/.bashrc;\
        echo "export OMPI_MCA_btl_vader_single_copy_mechanism=none" >> ~feelpp/.bashrc

USER vscode
