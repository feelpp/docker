#!/usr/bin/env bash
#
# This script generate singularity bootstrap per Feel++ docker images
# Usage: ./generate_bootstrap.sh <image:branch>
#

if [ $# -eq 0 ]; then
    echo "Usage: ./generate_bootstrap.sh <dockerimage>"
    exit 0;
fi

################################################################################
# DOCKER INSTALL IS REQUIRED
DOCKERPULL="$1"
SINGULARITYPADDING=500
BASEIMAGETAG=`basename ${DOCKERPULL}`
BASEIMAGE=`echo "${BASEIMAGETAG}" | sed 's/:.*//'`
TAG=latest
if [[ "${BASEIMAGETAG}" == *":"* ]]; then
    TAG=`echo "${BASEIMAGETAG}" | sed "s/.*://"`
fi
ROOTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
BOOTSTRAPDIR=${ROOTDIR}/${BASEIMAGE}/
BOOTSTRAP=singularity-${TAG}.def
IMAGEDIR=$BOOTSTRAPDIR

DOCKERIMAGE=${BASEIMAGE}:${TAG}
SINGULARITYIMAGE=singularity_${BASEIMAGE}-${TAG}.img
################################################################################
