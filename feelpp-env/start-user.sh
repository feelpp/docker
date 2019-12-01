#!/bin/bash

set -x
#USER_ID=$(id -u)

#echo "Starting with UID : $USER_ID"
#useradd -m -s /bin/bash -d /home/$USER -u $USER_ID -G sudo,video,docker user
#echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
#export HOME=/home/$USER

#sudo cp /home/feelpp/feelpp*.sh $HOME 
#sudo cp /home/feelpp/WELCOME $HOME

#chown -R user.user $HOME
#echo "login as user $USER with id $USER_ID"
#/usr/sbin/gosu ${USER} bash --rcfile /usr/local/etc/bashrc.feelpp
#}

exec /bin/bash --rcfile /usr/local/etc/bashrc.feelpp
