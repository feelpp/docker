#!/bin/bash

set -euo pipefail
if [ -d /feel/crbdb ]; then
    sudo service mongodb start
    if [ -d /feel/crbdb/mongodb ]; then
        /usr/lib/juju/mongo3.2/bin/mongorestore /feel/crbdb/mongodb
    fi
fi

usermod -u $UID feelpp
groupmod -g $UID feelpp

chown -R feelpp:feelpp /home/feelpp/

exec "$@"

