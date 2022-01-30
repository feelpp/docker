#!/bin/bash

USER_ID=${LOCAL_USER_ID:-9001}

echo "Starting with UID : $USER_ID"
useradd -m -s /bin/bash -d /home/user -u $USER_ID -G sudo,video,docker user
echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
export HOME=/home/user

sudo cp /home/feelpp/feelpp*.sh $HOME 
sudo cp /home/feelpp/WELCOME $HOME

chown -R user.user $HOME

cat > $HOME/.feelppconfig << EOF
{
 "append_date": false,
 "append_np": true,
 "feelppdb": "feelppdb",
 "exprs": "exprs",
 "geos": "geo",
 "location": "global",
 "logs": "logs",
 "owner": {
  "email": "",
  "name": "user"
 },
 "global_root":"/feelppdb"
}
EOF
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

if [ -d /feelppdb/crbdb ]; then
    sudo service mongodb start
    if [ -d /feelppdb/crbdb/mongodb ]; then
        /usr/lib/juju/mongo3.2/bin/mongorestore /feelppdb/crbdb/mongodb
    fi
fi

if ! [ -d /feelppdb/ -a -w /feelppdb/ -a -d  /usr/local/share/feelpp/testcases/ ]; then
    mkdir -p /feelppdb
fi
cp -r  /usr/local/share/feelpp/testcases /feelppdb/
chown -R user.user /feelppdb/testcases
echo ""
echo "The Feel++ testcases have been copied on the host system in"
echo "/feelppdb/testcases"
echo "ls /feelppdb/testcases"
ls /feelppdb/testcases/
echo "You can use and edit them as you which either within docker or on your system"
echo ""

exec /usr/sbin/gosu user bash
