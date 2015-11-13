#!/bin/bash

# set feelpp home
export SRC_DIR=${HOME}/src
mkdir -p $SRC_DIR

export FEELPP_HOME=${SRC_DIR}/build
mkdir -p $FEELPP_HOME

# bash functions
pull_feelpp ()
{
  echo "Pulling feelpp..."
  cd $SRC_DIR
  if [ -d feelpp ]
  then
	 cd feelpp
 	 git pull
  else
	 git clone --depth 1 https://www.github.com/feelpp/feelpp.git
     cd feelpp
     git submodule update --init --recursive contrib/nlopt
     git submodule update --init --recursive quickstart
  fi
}
build_feelpp()
{
  echo "Building Feel++..."
  if [ -d $SRC_DIR/feelpp ]
  then
        cd $FEELPP_HOME
    	${SRC_DIR}/feelpp/configure -r --cmakeflags="-DFEELPP_ENABLE_VTK_INSITU=ON "
        make install-feelpp-lib
  else
	   echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
install_feelpp()
{
  pull_feelpp
  build_feelpp
}
