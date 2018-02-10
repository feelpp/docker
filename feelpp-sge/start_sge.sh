#!/bin/bash

sudo service gridengine-master restart
sudo service gridengine-exec restart

# create a host list
echo -e "group_name @allhosts\nhostlist NONE" > /tmp/grid
sudo qconf -Ahgrp /tmp/grid
rm /tmp/grid

# scheduler config
sudo qconf -Msconf /etc/sge-feelpp/scheduler_template

# queue config
sudo qconf -Aq /etc/sge-feelpp/queue_template

# add the current host to the submit host list (will be able to do qsub)
sudo qconf -as $HOSTNAME

# add to the admin host list so that we can do qstat, etc.
sudo qconf -ah $HOSTNAME

# add a worker
sudo /etc/sge-feelpp/sge-worker-add.sh feelpp.q $HOSTNAME $(nproc)


sudo service gridengine-master restart
sudo service gridengine-exec restart
