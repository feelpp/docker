# -*- mode: Dockerfile -*-

FROM ghcr.io/feelpp/feelpp-toolboxes:latest

USER root
RUN apt-get update;\
        apt-get install -y --no-install-recommends git git-lfs jq curl; \
        apt-get install -y --no-install-recommends 'libfeelpp-toolboxes*-dev';\
        rm -rf /var/lib/apt/lists/* ;

RUN json=$(curl -s "https://api.github.com/repos/Kitware/CMake/releases"); \
        latest_tag=$(echo $json | jq -r '.[] | select(.prerelease==false).tag_name' | sort --unique --version-sort | grep -v "rc" | tail -1);\
	sh_url=$(echo $json | jq -r ".[] | select(.tag_name==\"${latest_tag}\").assets[].browser_download_url | select(endswith(\"inux-x86_64.sh\"))");\
	curl -sL ${sh_url} -o cmakeinstall.sh \
	&& chmod +x cmakeinstall.sh \
	&& ./cmakeinstall.sh --prefix=/usr/local --exclude-subdir \
	&& rm cmakeinstall.sh

USER feelpp
