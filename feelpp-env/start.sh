#!/bin/bash

USER_ID=${LOCAL_USER_ID:-9001}

echo "Starting with UID : $USER_ID"
useradd -m -s /bin/bash -d /home/user -u $USER_ID -G sudo,video,docker user
echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
export HOME=/home/user

sudo cp /home/feelpp/feelpp*.sh $HOME 
sudo cp /home/feelpp/WELCOME $HOME

chown -R user.user $HOME

# OpenBLAS threads should be 1 to ensure performance
echo "export OPENBLAS_NUM_THREADS=1" >> $HOME/.bashrc 
echo "export OPENBLAS_VERBOSE=0" >> $HOME/.bashrc

# This makes sure we launch with ENTRYPOINT /bin/bash into the home directory
echo "export FEELPP_DEP_INSTALL_PREFIX=${FEELPP_DEP_INSTALL_PREFIX}" >> $HOME/.bashrc 
echo "export CC=$CC" >> $HOME/.bashrc 
echo "export CXX=$CXX" >> $HOME/.bashrc
echo "export USER=user" >> $HOME/.bashrc
echo "source $HOME/feelpp.env.sh" >> $HOME/.bashrc 
echo "source $HOME/feelpp.conf.sh" >> $HOME/.bashrc 
echo "cd $HOME" >> $HOME/.bashrc 
echo "cat $HOME/WELCOME" >> $HOME/.bashrc

if [ -d /feel/crbdb ]; then
    sudo service mongodb start
    if [ -d /feel/crbdb/mongodb ]; then
        /usr/lib/juju/mongo3.2/bin/mongorestore /feel/crbdb/mongodb
    fi
fi

if [ -d /feel/ -a -w /feel/ -a -d  /usr/local/share/feelpp/testcases/ ]; then
    cp -r  /usr/local/share/feelpp/testcases /feel/
    chown -R user.user /feel/testcases
    echo ""
    echo "The Feel++ testcases have been copied on the host system in"
    echo "/feel/testcases"
    echo "ls /feel/testcases"
    ls /feel/testcases/
    echo "You can use and edit them as you which either within docker or on your system"
    echo ""
fi
exec /usr/sbin/gosu user bash
