FROM feelpp/dev-env:latest
MAINTAINER Feel++ Support <support@feelpp.org>

USER feelpp
ENV HOME /home/feelpp

COPY feelpp.conf.sh $HOME/feelpp.conf.sh

# Source config for further use
RUN bash -c 'echo -e "# Source configuration for Feel++\nsource $HOME/feelpp.conf.sh" >> ${HOME}/.bashrc'

# Install Feel++
RUN bash -c "source $HOME/feelpp.conf.sh && install_feelpp"

# COPY WELCOME $HOME/WELCOME
USER root
ENTRYPOINT ["/sbin/my_init","--quiet","--","sudo","-u","feelpp","/bin/sh","-c"]
CMD ["/bin/bash"]
