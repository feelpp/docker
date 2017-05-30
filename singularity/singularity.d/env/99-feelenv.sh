#!/usr/bin/env bash

LSHOME=`ls -A ${HOME}`
echo -e "\e[1;34m"
echo -e "$(cat /opt/feelpp/WELCOME)"
echo -e "\e[1;31m"

if [ -z "$LSHOME" ]; then
    # users use '-c' singularity shell option
    cp -r /opt/feelpp/* ${HOME}/
    echo -e "Modifications in ${HOME} are not saved once you quit the container! 
(Use a bind directory '-B <src>:<dest>')"
else
    export FEELPP_CONTAINER_HOME=${HOME}/feelpp-containers/${SINGULARITY_CONTAINER}
    # users do not use '-c' singularity shell option
    if ! [ -d ${FEELPP_CONTAINER_HOME} ]; then
        cp -r /opt/feelpp/* ${FEELPP_CONTAINER_HOME}
        echo -e "Modifications are saved in ${FEELPP_CONTAINER_HOME}"
    else
        echo -e "Use existing ${FEELPP_CONTAINER_HOME} (remove this directory and 
rerun the container to reset the tutorial)"
    fi
    cd ${FEELPP_CONTAINER_HOME}
fi
echo -e "\e[0m"

PS1="\[\e[1;37m\][singularity]: \[\e[1;36m\]\u@\h\[\e[0m\]:\w> "
export PS1
