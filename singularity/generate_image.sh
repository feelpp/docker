#!/usr/bin/env bash
#
# This script generate singularity bootstrap per docker images
# Usage: ./generate_bootstrap.sh <image:branch>
#

source include_path.sh

if ! [[ "$(docker images -q ${BASEIMAGETAG})" == "" ]]; then
    if [ ! -f "${BOOTSTRAPDIR}/${BOOTSTRAP}" ]; then
        echo "Bootstrap: ${BOOTSTRAPDIR}/${BOOTSTRAP} not found!"
        echo "You should run './generate_bootstrap.sh ${BASEIMAGETAG}' first!"
        exit 1
    fi

    echo "Getting size for $BASEIMAGETAG"
    # Get human readable image size from docker.
    imagesizeh=`docker images --format "{{ .Size }}" "${BASEIMAGETAG}" | sed "s/B//g" | sed "s/\ *//g"`
    echo "Docker image size ${imagesizeh}"
    ## Convert to MB real size.
    export LC_ALL=C
    imagesizebyte=`numfmt --from=auto ${imagesizeh}`
    export LC_ALL=""
    IMAGESIZE=`echo "${imagesizebyte}/(1000*1000)+${SINGULARITYPADDING}" | bc`
    echo "Docker generate image  ${IMAGESIZE} MiB"
    
    singularity create --force --size "${IMAGESIZE}" "${IMAGEDIR}/${SINGULARITYIMAGE}"
    # MUST BE SUDO HERE!
    sudo singularity bootstrap --force "${IMAGEDIR}/${SINGULARITYIMAGE}" "${BOOTSTRAPDIR}/${BOOTSTRAP}"
else
    echo -e "error: $0:\nLocal docker image ${DOCKERIMAGE} does not exist! You might want to do 'docker pull ${DOCKERIMAGE}' first"
    exit 1
fi
