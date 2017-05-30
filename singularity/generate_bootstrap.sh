#!/usr/bin/env bash
#
# This script generate singularity bootstrap per Feel++ docker images
# Usage: ./generate_bootstrap.sh <image:branch>
#

source include_path.sh

set -e

if ! [[ "$(docker images -q ${BASEIMAGETAG})" == "" ]]; then
    if [ -d ${BOOTSTRAPDIR} ]; then
        echo -e "warning: $0:\nDirectory "${BOOTSTRAPDIR}" is being created!"
    fi
    echo "Using docker image: ${DOCKERIMAGE}"
    mkdir -p ${BOOTSTRAPDIR}
    echo "Generate bootstrap file: ${BOOTSTRAPDIR}${BOOTSTRAP}"
    cat ./bootstrap.def | sed "s/From:.*$/From: ${BASE}\/${IMAGE}:${TAG}/g" > "${BOOTSTRAPDIR}/${BOOTSTRAP}"
    cp -r ./singularity.d ${BOOTSTRAPDIR}/
else
    echo -e "error: $0:\nLocal docker image ${DOCKERIMAGE} does not exist! You might want to do 'docker pull ${DOCKERIMAGE}' first"
    exit 1
fi

set +e
