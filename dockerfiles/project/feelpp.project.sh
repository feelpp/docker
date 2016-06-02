#!/bin/bash

# bash functions
build_project()
{
  echo "Building Project $1 ..."
  if [ -d ${FEELPP_SRC_DIR}/feelpp ]
  then
        export FEELPP_DIR=/usr/local
        cd /tmp
        git clone $2 $1
        # /tmp should only have the directory of our project
        # so we can do cd `ls`
        cd $1 && mkdir build && cd build
        cmake /tmp/$1 -DCMAKE_PREFIX_PATH=${FEELPP_HOME}
        make -j $3
  else
	   echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
