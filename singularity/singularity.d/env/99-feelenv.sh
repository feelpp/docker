#!/usr/bin/env bash

red=`tput setaf 1`
blue=`tput setaf 4`
reset=`tput sgr0`
bold=`tput bold`
escleft=`if [ "${SHELL##*/}" == "bash" ]; then echo '\['; fi`
escright=`if [ "${SHELL##*/}" == "bash" ]; then echo '\]'; fi`
welcome=`cat /opt/feelpp/WELCOME`

LSHOME=`ls -A ${HOME}`
echo "${bold}${blue}"
echo "${welcome}"
echo "${red}"

if [ -z "$LSHOME" ]; then
    # users use '-c' singularity shell option
    echo "Modifications in ${HOME} are not saved once you quit the container!
(option '-B <src>:<dest>')"
else
    # users do not use '-c' singularity shell option
        echo "Copy  '${FEELPP_TUTORIAL}' in ${HOME} to save modifications. Or use a bind directory!
(option '-B <src>:<dest>')"
fi
echo "${reset}"

cd ${FEELPP_TUTORIAL}

