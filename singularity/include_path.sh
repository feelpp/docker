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
SINGULARITY_BIN=`which singularity`
SINGULARITYPADDING=500
DOCKERIMAGE=$1
BASEIMAGE=`echo "${DOCKERIMAGE}" | sed 's/:.*//'`
BASE=`echo "${BASEIMAGE}" | sed 's/\/.*//'`
IMAGE=`echo "${BASEIMAGE}" | sed 's/.*\///'`
TAG_FROM_DOCKER_IMAGE=`echo "${DOCKERIMAGE}" | sed "s/.*://"`
TAG=${FEELPP_DOCKER_TAG:-${TAG_FROM_DOCKER_IMAGE}}
if [ ! -n "$TAG" ] || [ "$TAG" ==  "$DOCKERIMAGE" ]; then
    TAG=${latest}
fi
BASEIMAGETAG=${BASE}/${IMAGE}:${TAG}
echo $BASEIMAGETAG
ROOTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
BOOTSTRAPDIR=${ROOTDIR}/singularity/images/${BASE}/${IMAGE}/${TAG}/
BOOTSTRAP=Singularity
IMAGEDIR=$BOOTSTRAPDIR

SINGULARITYIMAGE=singularity_${BASE}_${IMAGE}-${TAG}.img
################################################################################
