#!/bin/bash

# set feelpp home
export FEELPP_SRC_DIR=${HOME}/src
mkdir -p ${FEELPP_SRC_DIR}

export FEELPP_BUILD_DIR=${HOME}/build
mkdir -p ${FEELPP_BUILD_DIR}

export FEELPP_HOME=/usr/local
mkdir -p ${FEELPP_HOME}

export PATH=${FEELPP_HOME}/bin:${PATH}
export LD_LIBRARY_PATH=${FEELPP_HOME}/lib:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=${FEELPP_HOME}/lib/pkgconfig:$PKG_CONFIG_PATH
export PYTHONPATH=${FEELPP_HOME}/lib/python2.7/site-packages:$PYTHONPATH
export MANPATH=${FEELPP_HOME}/share/man:$MANPATH

# bash functions
pull_feelpp ()
{
  echo "Pulling feelpp..."
  cd ${FEELPP_SRC_DIR}
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
  if [ -d ${FEELPP_SRC_DIR}/feelpp ]
  then
        cd ${FEELPP_BUILD_DIR}
    	${FEELPP_SRC_DIR}/feelpp/configure -r --cmakeflags="-DFEELPP_ENABLE_VTK_INSITU=ON -DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} "
        sudo make -j 16 install-feelpp-base
  else
	   echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
install_feelpp()
{
  pull_feelpp
  build_feelpp
}
