# -*- mode: Dockerfile -*-

FROM ubuntu:focal

ARG CHANNEL
ENV CHANNEL=${CHANNEL:-latest}
RUN apt-get update \
        && apt-get install -y \
        vim \
        ssh \
        sudo \
        wget \
        software-properties-common ;\
        rm -rf /var/lib/apt/lists/*

RUN useradd --user-group --create-home --shell /bin/bash feelpp ;\
        echo "feelpp ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

        

RUN wget -qO - https://feelpp.jfrog.io/artifactory/api/security/keypair/gpg-debian/public | apt-key add -; \
        echo "deb https://feelpp.jfrog.io/artifactory/ubuntu focal ${CHANNEL}" | tee -a /etc/apt/sources.list.d/feelpp.list;\
        apt-get update ;\
        apt-get install -y --no-install-recommends feelpp-toolboxes feelpp-toolboxes-data libfeelpp-toolboxes1-all-dev feelpp-tools python3-feelpp-toolboxes make rsync;\
        rm -rf /var/lib/apt/lists/* ;

RUN     echo "export FEELPP_REPOSITORY=/feel" >> ~feelpp/.bashrc;\
        echo "export OMPI_MCA_btl_vader_single_copy_mechanism=none" >> ~feelpp/.bashrc

USER feelpp
