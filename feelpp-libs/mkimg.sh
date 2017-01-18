#!/bin/bash

set -e

mkimg="$(basename "$0")"

from=ubuntu:16.10
cxx=g++
cc=gcc
jobs=20
cxxflags=""
cmakeflags=""
branch=develop
version=1.0
nocache=true
travis=false

usage() {
    echo >&2 "usage: $mkimg [-f os-version] [-t tag]"
    echo >&2 "              [-b|--branch Feel++ git branch]"
    echo >&2 "              [-j|--jobs number of make parallel jobs] "
    echo >&2 "              [-c|--cmakeflags= cmake flags]"
    echo >&2 "              [-v|--version version of feel++,default: 1.0]"
    echo >&2 "              [--cxx c++ compiler, default: g++]"
    echo >&2 "              [--cc c compiler, default: gcc]"
    echo >&2 "              [--cxxflags c++ flags]"
    echo >&2 "              [--no-cache true|false]"
    echo >&2 "              [--travis true|false, default=false]"
    echo >&2 "   ie: $mkimg -f debian:sid  -c clang++ "
    exit 1
}

fromos=
fromtag=

tag=
while [ -n "$1" ]; do
    case "$1" in
        -f|--from) from="$2" ; shift 2 ;;
        -t|--tag) tag="$2" ; shift 2 ;;
        -b|--branch) branch="$2" ; shift 2 ;;
        -j|--jobs) jobs="$2" ; shift 2 ;;
        -c|--cmakeflags) cmakeflags="$2" ; shift 2 ;;
        --cxx) cxx="$2" ; shift 2 ;;
        --cc) cc="$2" ; shift 2 ;;
        --cxxflags) cxxflags="$2" ; shift 2 ;;
        --no-cache) nocache="$2" ; shift 2 ;;
        --travis) travis="$2" ; shift 2 ;;
        -v|--version) version="$2" ; shift 2 ;;
        -h|--help) usage ;;
        --) shift ; break ;;
    esac
done

splitfrom=(`echo "$from" | tr ":" "\n"`)
fromos=${splitfrom[0]}
fromtag=${splitfrom[1]}

if [ -z $tag ]; then
    tag=feelpp/feelpp-libs:$(echo "${branch}" | sed -e 's/\//-/g')-${fromos}-${fromtag}
fi

echo >&2 "directory $branch-$fromos-$fromtag"
dir=$branch-$fromos-$fromtag-$cxx
if [ ! -d "$dir" ]; then
    (set -x; mkdir -p "$dir")
fi

echo >&2 "+ cat > '$dir/Dockerfile'"
cat > "$dir/Dockerfile" <<EOF
FROM feelpp/feelpp-env:${fromos}-${fromtag}
MAINTAINER Feel++ Support <support@feelpp.org>

ARG BRANCH=${branch}
ARG BUILD_JOBS=${jobs}
ARG CMAKE_FLAGS="${cmakeflags}"
ARG CXXFLAGS="${cxxflags}"
ARG VERSION="${version}"
ARG CXX="${cxx}"
ARG CC="${cc}"
ARG TRAVIS="${travis}"

LABEL org.feelpp.vendor="Cemosis" \
      org.feelpp.version="${VERSION}"

EOF

cat Dockerfile-feelpp >> "$dir/Dockerfile"

cp WELCOME.libs $dir

( set -x; docker build -t $tag --no-cache=$nocache $dir )
