#!/bin/bash

QUEUE=$1
HOSTNAME=$2

# disable the host to avoid any jobs to be allocated to this host
qmod -d $QUEUE@$HOSTNAME

# remove it from the all hosts list
qconf -dattr hostgroup hostlist $HOSTNAME @allhosts

# remove it from the execution host list
qconf -de $HOSTNAME

# delete specific slot count for the host
qconf -purge queue slots $QUEUE@$HOSTNAME