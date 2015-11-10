FROM feelpp/dev-env:latest
MAINTAINER Feel++ Support <support@feelpp.org>

USER feelpp
ENV HOME /home/feelpp

RUN /bin/bash -c "source $HOME/feelpp.conf && install_feelpp"

# COPY WELCOME $HOME/WELCOME
USER root
ENTRYPOINT ["/sbin/my_init","--quiet","--","sudo","-u","feelpp","/bin/sh","-c"]
CMD ["/bin/bash --rcfile /home/feelpp/.bashrc.tmp"]
