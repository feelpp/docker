#!/bin/bash

DEFAULT_BRANCH=develop
DEFAULT_NJOBS=1

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
      git pull --depth 1 origin ${1:-${DEFAULT_BRANCH}}
  else
      git clone --depth 1 --branch ${1:-${DEFAULT_BRANCH}} https://www.github.com/feelpp/feelpp.git
      cd feelpp
      git submodule update --init --recursive contrib/nlopt
  fi
}
configure_feelpp()
{
    cd ${FEELPP_BUILD_DIR}/
    if [[ $CXXFLAGS ]]; then
    	${FEELPP_SRC_DIR}/feelpp/configure -r --cxxflags="${CXXFLAGS}" --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} $*";
    else
        ${FEELPP_SRC_DIR}/feelpp/configure -r --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} $*";
    fi
}
build_feelpp_libs()
{
  echo "Building Feel++ Libs..."
  if [ -d ${FEELPP_SRC_DIR}/feelpp ]
  then
      # Get the number of jobs to be used
      NJOBS=${1:-${DEFAULT_NJOBS}}
      shift
      # $* now contains possible additional cmake flags
      configure_feelpp $*
      echo "Travis: ${TRAVIS}"
      if [ ${TRAVIS} ]; then
          sudo make -j 4 contrib
      fi
      sudo make -j $NJOBS install-feelpp-lib
  else
      echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
clean_feelpp()
{
    rm -rf ${FEELPP_BUILD_DIR}/*
    echo -e "\033[33;32m--- Cleaning done. \033[0m"
}

# install Feel++ libs
install_feelpp_libs()
{
    pull_feelpp ${1:-${DEFAULT_BRANCH}}
    build_feelpp_libs ${2:-${DEFAULT_NJOBS}}
    clean_feelpp
}

#
# Feel++ Base
configure_feelpp_base()
{
    echo "--- Configuring Feel++ Base..."
    cd $HOME
    cd ${FEELPP_BUILD_DIR}/
    if [[ $CXXFLAGS ]]; then
    	${FEELPP_SRC_DIR}/feelpp/quickstart/configure -r --root="${FEELPP_SRC_DIR}/feelpp/quickstart" --cxxflags="${CXXFLAGS}" --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} $*";
    else
        ${FEELPP_SRC_DIR}/feelpp/quickstart/configure -r --root="${FEELPP_SRC_DIR}/feelpp/quickstart" --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} $*";
    fi
    echo -e "\033[33;32m--- Configuring Feel++ Base done. \033[0m"
}

build_feelpp_base()
{
    echo "--- Building Feel++ Base..."
    if [ -d ${FEELPP_SRC_DIR}/feelpp ]
    then
        # Get the number of jobs to be used
        NJOBS=${2:-${DEFAULT_NJOBS}}
        echo $NJOBS
        #shift
        # $* now contains possible additional cmake flags
        configure_feelpp_base ${@:3}
        make -j $NJOBS
        make test
        sudo make install
    else
        echo "Feel++ source cannot be found. Please run pull_feelpp first."
    fi
    echo -e "\033[33;32m--- Build Feel++ Base done. \033[0m"
}

# install_feelpp_base <NJOBS:1>
install_feelpp_base()
{
  build_feelpp_base ${1:-${DEFAULT_NJOBS}} ${*:2}
  clean_feelpp
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
        shift
        configure_feelpp $*
        sudo make -j $NJOBS install-feelpp-apps
    else
        configure_feelpp $*
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
