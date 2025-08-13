#!/usr/bin/env bash
set -euo pipefail

mkimg="$(basename "$0")"

from="debian:10"
cxx="clang++"
cc="clang"
token=""
install_altair=""
tag=""

usage() {
  echo >&2 "usage: $mkimg [-f fromos:fromtag] [-t tag] [-c c++ compiler] [-cc c compiler] [-o token] [-a 0|1]"
  echo >&2 "   ex: $mkimg -f debian:13 -t feelpp-env:debian-13 -c clang++ -cc clang"
  exit 1
}

# ---- Parse args (no need for trailing --) ----
while (($#)); do
  case "$1" in
    -a|--altair) install_altair="${2:-}"; shift 2 ;;
    -f|--from)   from="${2:-}";          shift 2 ;;
    -t|--tag)    tag="${2:-}";           shift 2 ;;
    -c|--cxx)    cxx="${2:-}";           shift 2 ;;
    -cc)         cc="${2:-}";            shift 2 ;;
    -o|--token)  token="${2:-}";         shift 2 ;;
    -h|--help)   usage ;;
    --)          shift; break ;;
    *)           echo "Unknown option: $1" >&2; usage ;;
  esac
done

# ---- Split FROM into os:tag safely ----
if [[ "$from" != *:* ]]; then
  echo "ERROR: --from/-f must be of the form os:tag (got '$from')" >&2
  exit 1
fi
fromos="${from%%:*}"
fromtag="${from#*:}"

# ---- Build directory ----
dir="${fromos}-${fromtag}-${cxx}"
mkdir -p "$dir"

# ---- Start Dockerfile ----
{
  echo "FROM $from"
  echo 'LABEL maintainer="Feel++ Support <support@feelpp.org>"'
  cat <<EOF
ARG FLAVOR="$fromos"
ARG FLAVOR_VERSION="$fromtag"
ARG BRANCH=develop
ARG BUILD_JOBS=1
ARG CMAKE_FLAGS=""
ARG VERSION="1.0"
ARG CXX="${cxx}"
ARG CC="${cc}"
ARG TOKEN="${token}"
ENV FEELPP_DEP_INSTALL_PREFIX=/usr/local

LABEL org.feelpp.vendor="Cemosis" \
      org.feelpp.version="\${VERSION}"
EOF
} > "$dir/Dockerfile"

# ---- Concatenate optional fragments if present ----
append_if_exists() {
  local f="$1"
  if [[ -f "$f" ]]; then
    { cat "$f"; echo; } >> "$dir/Dockerfile"
  fi
}

append_if_exists "Dockerfile-${fromos}"
append_if_exists "Dockerfile-${fromos}-${fromtag}"

# Include OpenMPI / deb-om layer for all but Fedora and Ubuntu 24.04
if [[ "$fromos" != "fedora" && "$fromtag" != "24.04" && "$fromtag" != "13" ]]; then
  if [[ -f "Dockerfile-deb-om-${fromos}-${fromtag}" ]]; then
    append_if_exists "Dockerfile-deb-om-${fromos}-${fromtag}"
  else
    append_if_exists "Dockerfile-deb-om"
  fi
fi

# CMake layer only for Ubuntu 20.04 (legacy)
if [[ "$fromtag" == "20.04" ]]; then
  append_if_exists "Dockerfile-cmake"
fi

append_if_exists "Dockerfile-feelpp"

# Final ENV
echo 'ENV PATH=/usr/local/bin:$PATH' >> "$dir/Dockerfile"

# ---- Copy aux files if they exist ----
shopt -s nullglob
for f in WELCOME start.sh start-user.sh bashrc.feelpp feelpp.* ctest*xsl; do
  [[ -e "$f" ]] && cp "$f" "$dir"/
done
[[ -d qt6 ]] && cp -r qt6 "$dir"/

echo "Base: $from  -> Dockerfile: ${dir}/Dockerfile" >&2
echo "$dir"