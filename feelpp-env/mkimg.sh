#!/bin/bash
set -e

mkimg="$(basename "$0")"

from=debian:10
cxx=clang++
cc=clang
token=

usage() {
    echo >&2 "usage: $mkimg [-f fromos:fromtag] [-t tag] [-c c++ compiler] [-cc c compiler]"
    echo >&2 "   ie: $mkimg -f $from -t feelpp-env:19.10 -c clang++ -cc clang "
    exit 1
}

fromos=
fromtag=
install_altair=

tag=
while true; do
    case "$1" in
        -a|--altair) install_altair="$2" ; shift 2 ;;
        -f|--from) from="$2" ; shift 2 ;;
        -t|--tag) tag="$2" ; shift 2 ;;
        -c|--cxx) cxx="$2" ; shift 2 ;;
        -o|--token) token="$2" ; shift 2 ;;
        -cc) cc="$2" ; shift 2 ;;
        -h|--help) usage ;;
        --) shift ; break ;;
    esac
done

splitfrom=(`echo "$from" | tr ":" "\n"`)
fromos=${splitfrom[0]}
fromtag=${splitfrom[1]}

#echo >&2 "directory $fromos-$fromtag"
dir=$fromos-$fromtag-$cxx
if [ ! -d "$dir" ]; then
    #(set -x; mkdir "$dir")
    mkdir "$dir"
fi

#echo >&2 "+ cat > '$dir/Dockerfile'"
cat > "$dir/Dockerfile" <<EOF
FROM $from
MAINTAINER Feel++ Support <support@feelpp.org>

ARG FLAVOR="$fromos"
ARG FLAVOR_VERSION="$fromtag"
ARG BRANCH=develop
ARG BUILD_JOBS=1
ARG CMAKE_FLAGS=""
ARG VERSION="1.0"
ARG CXX="${cxx}"
ARG CC="${cc}"
ARG TOKEN="${token}"
ENV FEELPP_DEP_INSTALL_PREFIX /usr/local

LABEL org.feelpp.vendor="Cemosis" \
      org.feelpp.version="${VERSION}"

EOF

if test -f Dockerfile-$fromos; then
    ( cat "Dockerfile-$fromos"; echo )  >> "$dir/Dockerfile"
fi
if test -f Dockerfile-$fromos-$fromtag; then
    ( cat "Dockerfile-$fromos-$fromtag"; echo ) >> "$dir/Dockerfile"
fi

if test $fromos != "fedora"; then
    if test -f Dockerfile-deb-om-$fromos-$fromtag; then
        ( cat "Dockerfile-deb-om-$fromos-$fromtag"; echo )  >> "$dir/Dockerfile"
    else
        ( cat Dockerfile-deb-om; echo )  >> "$dir/Dockerfile"
    fi
fi

( cat Dockerfile-cmake; echo ) >> "$dir/Dockerfile"

#cat Dockerfile-openmpi >> "$dir/Dockerfile"

#cat Dockerfile-boost >> "$dir/Dockerfile"

#cat Dockerfile-petsc-slepc >> "$dir/Dockerfile"

#if [ "x$install_altair" = "x1" ]; then
#cat Dockerfile-altair >> "$dir/Dockerfile"
#fi

#cat Dockerfile-paraview-$fromos-$fromtag >> "$dir/Dockerfile"

#cat Dockerfile-deb-mongodb-$fromos-$fromtag >> "$dir/Dockerfile"

#cat Dockerfile-openturns >> "$dir/Dockerfile"

#cat Dockerfile-deb-sympy >> "$dir/Dockerfile"

#cat Dockerfile-deb-mpi4py >> "$dir/Dockerfile"

#cat Dockerfile-fmi >> "$dir/Dockerfile"

( cat "Dockerfile-$fromos-buildkite"; echo ) >> "$dir/Dockerfile"


( cat Dockerfile-feelpp; echo ) >> "$dir/Dockerfile"
( cat >> "$dir/Dockerfile"; echo ) <<EOF
ENV PATH=/usr/local/bin:$PATH
EOF

cp WELCOME ctest*xsl feelpp.* start.sh bashrc.feelpp start-user.sh $dir
cp -r qt6 $dir

#( set -x; echo "docker build -t $tag \"$dir\"" )
echo $dir
