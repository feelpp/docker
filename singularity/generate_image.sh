#!/usr/bin/env bash
#
# This script generate singularity bootstrap per docker images
# Usage: ./generate_bootstrap.sh <image:branch>
#

source include_path.sh

if ! [[ "$(docker images -q feelpp/${DOCKERIMAGE})" == "" ]]; then

    # Get human readable image size from docker.
    imagesizeh=`docker images --format "{{ .Size }}" "feelpp/${DOCKERIMAGE}" | sed "s/B//g" | sed "s/\ *//g"`;
    echo "Docker image size ${imagesizeh}"
    ## Convert to MB real size.
    export LC_ALL=C
    imagesizebyte=`numfmt --from=auto ${imagesizeh}`
    export LC_ALL=""
    IMAGESIZE=`echo "${imagesizebyte}/(1000*1000)+${SINGULARITYPADDING}" | bc`
    echo "Docker generate image  ${IMAGESIZE} MiB"
    
    if [ -d ${BOOTSTRAPDIR} ]; then
        echo "Generate bootstrap: ${BOOTSTRAPDIR}/${BOOTSTRAP}"
        cat ./bootstrap.def | sed "s/From:.*$/From: feelpp\/${DOCKERIMAGE}/g" > "${BOOTSTRAPDIR}/${BOOTSTRAP}"
    else
        echo -e "error: $0:\nDirectory ${BOOTSTRAPDIR} does not exist!"
        exit 1
    fi

    # MUST BE SUDO HERE!
    sudo singularity create --force --size "${IMAGESIZE}" "${IMAGEDIR}/${SINGULARITYIMAGE}"
    # MUST BE SUDO HERE!
    sudo singularity bootstrap --force "${IMAGEDIR}/${SINGULARITYIMAGE}" "${BOOTSTRAPDIR}/${BOOTSTRAP}"
else
    echo -e "error: $0:\nLocal docker image feelpp/${DOCKERIMAGE} does not exist! You might want to do 'docker pull feelpp/${DOCKERIMAGE}' first"
    exit 1
fi
