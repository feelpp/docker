FROM feelpp/develop:latest
MAINTAINER Feel++ Support <support@feelpp.org>

USER feelpp
ENV HOME /home/feelpp

COPY feelpp.crb.sh $HOME/feelpp.crb.sh

# Install Feel++
RUN bash -c "source $HOME/feelpp.conf.sh && source $HOME/feelpp.crb.sh && build_crb_app"

# COPY WELCOME $HOME/WELCOME
USER root
ENTRYPOINT ["/sbin/my_init","--quiet","--","sudo","-u","feelpp","/bin/sh","-c"]
CMD ["/bin/bash"]
