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
  git config --global user.name "Docker Robot"
  git config --global user.email "docker@feelpp.org"
  cd ${FEELPP_SRC_DIR}
  if [ -d feelpp ]
  then
	 cd feelpp
     git pull --depth 1 origin $1
  else
	 git clone --depth 1 --branch $1 https://www.github.com/feelpp/feelpp.git
     cd feelpp
     git submodule update --init --recursive contrib/nlopt
  fi
}
build_feelpp()
{
  echo "Building Feel++..."
  if [ -d ${FEELPP_SRC_DIR}/feelpp ]
  then
        # Get the number of jobs to be used
        NJOBS=$1
        shift
        # $* now contains possible additional cmake flags

        cd ${FEELPP_BUILD_DIR}
    	${FEELPP_SRC_DIR}/feelpp/configure -r --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} $*"
        sudo make -j $NJOBS install-feelpp-lib
  else
	   echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
clean_feelpp()
{
    rm -rf ${FEELPP_BUILD_DIR}
}

install_feelpp_quickstart()
{
  if [ -d ${FEELPP_SRC_DIR}/feelpp ]
  then
        # Get the number of jobs to be used
        NJOBS=$1
        shift
        cd ${FEELPP_BUILD_DIR}
        sudo make -j $NJOBS install-feelpp-base
  else
	   echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
  clean_feelpp
}
install_feelpp_models_fluid()
{
  if [ -d ${FEELPP_SRC_DIR}/feelpp ]
  then
        # Get the number of jobs to be used
        NJOBS=$1
        shift
        cd ${FEELPP_BUILD_DIR}
        sudo make -j $NJOBS install-apps-models-fluid
  else
	   echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
install_feelpp_models_solid()
{
  if [ -d ${FEELPP_SRC_DIR}/feelpp ]
  then
        # Get the number of jobs to be used
        NJOBS=$1
        shift
        cd ${FEELPP_BUILD_DIR}
        sudo make -j $NJOBS install-apps-models-solid
  else
	   echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
install_feelpp_models_fsi()
{
  if [ -d ${FEELPP_SRC_DIR}/feelpp ]
  then
        # Get the number of jobs to be used
        NJOBS=$1
        cd ${FEELPP_BUILD_DIR}
        sudo make -j $NJOBS install-apps-models-fsi
  else
	   echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
install_feelpp_models()
{
#    if [ -d ${FEELPP_SRC_DIR}/feelpp ]
    #    then
    if [[ $# -ge 1 ]]; then
        pull_feelpp $1
        shift 
    else
        pull_feelpp develop
    fi

    if [[ $# -ge 1 ]]; then
        # Get the number of jobs to be used
        NJOBS=$1
        cd ${FEELPP_BUILD_DIR}/
    	${FEELPP_SRC_DIR}/feelpp/configure -r --cmakeflags="-DCMAKE_INSTALL_PREFIX=/usr/local $*"        
        sudo make -j $NJOBS install-feelpp-apps
    else
        cd ${FEELPP_BUILD_DIR}/
    	${FEELPP_SRC_DIR}/feelpp/configure -r --cmakeflags="-DCMAKE_INSTALL_PREFIX=/usr/local $*"
        sudo make -j 20 install-feelpp-base
        sudo make -j 20 install-feelpp-apps
    fi
    sudo mkdir -p /usr/local/share/feel/testcases
    sudo make install-testcase
    
        
#    else
#	echo "Feel++ source cannot be found. Please run pull_feelpp first."
    #    fi
    clean_feelpp
}

install_feelpp_crb_apps()
{
  if [ -d ${FEELPP_SRC_DIR}/feelpp ]
  then
        # Get the number of jobs to be used
        NJOBS=$1
        cd ${FEELPP_BUILD_DIR}/applications/crb
        sudo make -j $NJOBS install
  else
	   echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
install_feelpp()
{
  if [[ $# -ge 1 ]]; then
      pull_feelpp $1
      shift 
  else
      pull_feelpp develop
  fi
  if [[ $# -ge 1 ]]; then
      build_feelpp $*
  else
      build_feelpp 20
  fi
  clean_feelpp
}
