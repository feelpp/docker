#!/bin/bash

set -e

# bash functions
build_project()
{
  echo "--- Building Project $1 ..."
  if [ -d ${FEELPP_SRC_DIR}/feelpp ]
  then
        export FEELPP_DIR=/usr/local
        cd /tmp
        mkdir $1
        cd $1
        git init
        git pull https://${GITHUB_OAUTH}@github.com/feelpp/$1.git $3
        #git clone $2 $1
        # /tmp should only have the directory of our project
        # so we can do cd `ls`
        mkdir build && cd build
        cmake /tmp/$1 -DCMAKE_PREFIX_PATH=${FEELPP_HOME}
        make -j $4
        # install requires sudo
        sudo make install
        if [ -f ../WELCOME.$1 ]; then
            sudo cp ../WELCOME.$1 $HOME/WELCOME;
        fi
  else
	   echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
clean_project(){
    rm -rf /tmp/$1
}
