#!/bin/bash
set -e

mkimg="$(basename "$0")"

from=ubuntu:16.10
cxx=clang++

usage() {
    echo >&2 "usage: $mkimg [-f fromos:fromtag] [-t tag] [-c c++ compiler]"
    echo >&2 "   ie: $mkimg -f $from -t feelpp-env:16.10 -c clang++ "
    exit 1
}

fromos=
fromtag=

tag=
while true; do
    case "$1" in
        -f|--from) from="$2" ; shift 2 ;;
        -t|--tag) tag="$2" ; shift 2 ;;
        -c|--cxx) cxx="$2" ; shift 2 ;;
        -h|--help) usage ;;
        --) shift ; break ;;
    esac
done

splitfrom=(`echo "$from" | tr ":" "\n"`)
fromos=${splitfrom[0]}
fromtag=${splitfrom[1]}

echo >&2 "directory $fromos-$fromtag"
dir=$fromos-$fromtag-$cxx
if [ ! -d "$dir" ]; then
    (set -x; mkdir "$dir")
fi

echo >&2 "+ cat > '$dir/Dockerfile'"
cat > "$dir/Dockerfile" <<EOF
FROM $from
MAINTAINER Feel++ Support <support@feelpp.org>

ARG BRANCH=develop
ARG BUILD_JOBS=1
ARG CMAKE_FLAGS=""
ARG VERSION="1.0"
ARG CXX="${cxx}"

LABEL org.feelpp.vendor="Cemosis" \
      org.feelpp.version="${VERSION}"

EOF

cat Dockerfile-$fromos-$fromtag >> "$dir/Dockerfile"

cat Dockerfile-feelpp >> "$dir/Dockerfile"

cp WELCOME feelpp.* $dir

( set -x; echo "docker build -t $tag \"$dir\"" )
