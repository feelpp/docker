#!/bin/bash

if [ -d /feel/crbdb ]; then
    sudo service mongodb start
    if [ -f /feel/crbdb/mongodb ]; then
        /usr/lib/juju/mongo3.2/bin/mongorestore /feel/crbdb/mongodb
    fi
fi
bash

