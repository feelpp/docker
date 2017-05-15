#!/usr/bin/env bash
#
# This script generate singularity bootstrap per Feel++ docker images
# Usage: ./generate_bootstrap.sh <image:branch>
#


source include_path.sh


set -e

if ! [[ "$(docker images -q feelpp/${DOCKERIMAGE})" == "" ]]; then
    if [ -d ${BOOTSTRAPDIR} ]; then
        echo "Generate bootstrap file: ${BOOTSTRAPDIR}${BOOTSTRAP}"
        cat ./bootstrap.def | sed "s/From:.*$/From: feelpp\/${DOCKERIMAGE}/g" > "${BOOTSTRAPDIR}/${BOOTSTRAP}"
    else
        echo -e "error: $0:\nDirectory "${BOOTSTRAPDIR}" does not exist!"
        exit 1
    fi
else
    echo -e "error: $0:\nImage feelpp/${DOCKERIMAGE} does not exist!"
    exit 1
fi

set +e
