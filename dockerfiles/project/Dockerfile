FROM feelpp/develop:latest
MAINTAINER Feel++ Support <support@feelpp.org>

ARG PROJECT_NAME="project"
ARG GIT_URL=""
ARG BUILD_JOBS=1

USER feelpp
ENV HOME /home/feelpp

COPY feelpp.project.sh $HOME/feelpp.project.sh

# Install Feel++
RUN bash -c "source $HOME/feelpp.conf.sh && source $HOME/feelpp.project.sh && build_project ${PROJECT_NAME} ${GIT_URL} ${BUILD_JOBS}"

# COPY WELCOME $HOME/WELCOME
USER root
ENTRYPOINT ["/sbin/my_init","--quiet","--","sudo","-u","feelpp","/bin/sh","-c"]
CMD ["/bin/bash"]
