# -*- mode: Dockerfile -*-

FROM ubuntu:focal

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

RUN useradd --user-group --create-home --shell /bin/bash feelpp ;\
        echo "feelpp ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

        

RUN wget -qO - http://apt.feelpp.org/apt.gpg | gpg --dearmor > feelpp.gpg; \
        install -o root -g root -m 644 feelpp.gpg /etc/apt/trusted.gpg.d; \
        echo "deb [signed-by=/etc/apt/trusted.gpg.d/feelpp.gpg] http://apt.feelpp.org/ubuntu focal ${CHANNEL}" | tee -a /etc/apt/sources.list.d/feelpp.list; \
	rm -f feelpp.gpg; \
        apt-get update ;\
        apt-get install -y --no-install-recommends feelpp-toolboxes feelpp-toolboxes-data; \
	apt-get install -y --no-install-recommends 'python3-feelpp-toolboxes*';\
	apt-get install -y --no-install-recommends make rsync;\
        rm -rf /var/lib/apt/lists/* ;

RUN     echo "export FEELPP_REPOSITORY=/feel" >> ~feelpp/.bashrc;\
        echo "export OMPI_MCA_btl_vader_single_copy_mechanism=none" >> ~feelpp/.bashrc

USER feelpp
