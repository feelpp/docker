FROM feelpp/dev-env:latest
MAINTAINER Feel++ Support <support@feelpp.org>

USER feelpp
ENV HOME /home/feelpp

COPY feelpp.conf.sh $HOME/feelpp.conf.sh

RUN /bin/bash -c "source $HOME/feelpp.conf.sh && install_feelpp"

# COPY WELCOME $HOME/WELCOME
USER root
ENTRYPOINT ["/sbin/my_init","--quiet","--","sudo","-u","feelpp","/bin/sh","-c"]
CMD ["/bin/bash"]
