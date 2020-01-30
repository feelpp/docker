# -*- mode: Dockerfile -*-

FROM ubuntu:eoan

RUN apt-get update \
        && apt-get install -y \
        vim \
        ssh \
        sudo \
        wget \
        software-properties-common ;\
        rm -rf /var/lib/apt/lists/*

RUN useradd --user-group --create-home --shell /bin/bash feelpp ;\
        echo "foam ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

        

RUN sh -c "wget -O - https://bintray.com/user/downloadSubjectPublicKey?username=bintray | apt-key add -" ;\
        echo "deb https://dl.bintray.com/feelpp/ubuntu eoan latest" | tee -a /etc/apt/sources.list;\
        apt-get update ;\
        apt-get install -y --no-install-recommends feelpp-toolboxes feelpp-toolboxes-data libfeelpp-toolboxes-dev feelpp-tools;\
        rm -rf /var/lib/apt/lists/* ;

RUN     echo "export FEELPP_REPOSITORY=/feel" >> ~feelpp/.bashrc;\
        echo "export OMPI_MCA_btl_vader_single_copy_mechanism=none" >> ~feelpp/.bashrc

USER feelpp
