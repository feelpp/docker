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
        sudo make -j $NJOBS install-feelpp-base
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


#
# Feel++ Toolboxes
configure_feelpp_toolboxes()
{
    echo "--- Configuring Feel++ Toolboxes..."
    cd $HOME
    cd ${FEELPP_BUILD_DIR}/
    if [[ $CXXFLAGS ]]; then
    	${FEELPP_SRC_DIR}/feelpp/configure -r --root="${FEELPP_SRC_DIR}/feelpp/toolboxes" --cxxflags="${CXXFLAGS}" --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} $*";
    else
        ${FEELPP_SRC_DIR}/feelpp/configure -r --root="${FEELPP_SRC_DIR}/feelpp/toolboxes" --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} $*";
    fi
    echo -e "\033[33;32m--- Configuring Feel++ Base done. \033[0m"
}

build_feelpp_toolboxes()
{
    echo "--- Building Feel++ Toolboxes..."
    if [ -d ${FEELPP_SRC_DIR}/feelpp ]
    then
        # Get the number of jobs to be used
        NJOBS=${2:-${DEFAULT_NJOBS}}
        echo $NJOBS
        #shift
        # $* now contains possible additional cmake flags
        configure_feelpp_toolboxes ${@:3}
        sudo make -j $NJOBS install
    else
        echo "Feel++ source cannot be found. Please run pull_feelpp first."
    fi
    echo -e "\033[33;32m--- Build Feel++ Toolboxes done. \033[0m"
}

# install_feelpp_toolboxes <NJOBS:1>
install_feelpp_toolboxes()
{
  build_feelpp_toolboxes ${1:-${DEFAULT_NJOBS}} ${*:2}
  clean_feelpp
}


#
# Feel++ CRB
configure_feelpp_crb()
{
    echo "--- Configuring Feel++ CRB..."
    cd $HOME
    cd ${FEELPP_BUILD_DIR}/
    if [[ $CXXFLAGS ]]; then
    	${FEELPP_SRC_DIR}/feelpp/configure -r --root="${FEELPP_SRC_DIR}/feelpp/applications/crb" --cxxflags="${CXXFLAGS}" --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} $*";
    else
        ${FEELPP_SRC_DIR}/feelpp/configure -r --root="${FEELPP_SRC_DIR}/feelpp/applications/crb" --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} $*";
    fi
    echo -e "\033[33;32m--- Configuring Feel++ CRB done. \033[0m"
}

build_feelpp_crb()
{
    echo "--- Building Feel++ CRB..."
    if [ -d ${FEELPP_SRC_DIR}/feelpp ]
    then
        # Get the number of jobs to be used
        NJOBS=${2:-${DEFAULT_NJOBS}}
        echo $NJOBS
        #shift
        # $* now contains possible additional cmake flags
        configure_feelpp_crb ${@:3}
        sudo make -j $NJOBS install
    else
        echo "Feel++ source cannot be found. Please run pull_feelpp first."
    fi
    echo -e "\033[33;32m--- Build Feel++ CRB done. \033[0m"
}

# install_feelpp_crb <NJOBS:1>
install_feelpp_crb()
{
  build_feelpp_crb ${1:-${DEFAULT_NJOBS}} ${*:2}
  clean_feelpp
}




