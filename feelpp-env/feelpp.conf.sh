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
      git submodule update --init --recursive 
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
      (cd cmake && make -j $NJOBS && sudo make install)
      (cd contrib && make -j $NJOBS && sudo make install)
      (cd feel && make -j $NJOBS && sudo make install )
      sudo make -j $NJOBS install-feelpp-lib
  else
      echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
clean_feelpp()
{
    sudo rm -rf ${FEELPP_BUILD_DIR}/*
}

# install Feel++ libs
install_feelpp_libs()
{
    exit_status=0
    BRANCH=${1:-${DEFAULT_BRANCH}}
    NJOBS=${2:-${DEFAULT_NJOBS}}
    pull_feelpp ${BRANCH}
    ((exit_status= $exit_status || $?))
    build_feelpp_libs ${NJOBS}
    ((exit_status= $exit_status || $?))
    install_feelpp_module ${BRANCH} pyfeelpp $HOME/src/feelpp/pyfeelpp ${NJOBS}
    ((exit_status= $exit_status || $?))
    clean_feelpp
    ((exit_status= $exit_status || $?))
    return $exit_status
}

#
# Feel++ Base
configure_feelpp_base()
{
    cd $HOME
    cd ${FEELPP_BUILD_DIR}/
    if [[ $CXXFLAGS ]]; then
    	${FEELPP_SRC_DIR}/feelpp/quickstart/configure -r --root="${FEELPP_SRC_DIR}/feelpp/quickstart" --cxxflags="${CXXFLAGS}" --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} $*";
    else
        ${FEELPP_SRC_DIR}/feelpp/quickstart/configure -r --root="${FEELPP_SRC_DIR}/feelpp/quickstart" --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} $*";
    fi
}

build_feelpp_base()
{
    echo "Building Feel++ Libs..."
    if [ -d ${FEELPP_SRC_DIR}/feelpp ]
    then
        # Get the number of jobs to be used
        NJOBS=${1:-${DEFAULT_NJOBS}}
        shift
        # $* now contains possible additional cmake flags
        configure_feelpp_base ${@:2}
        sudo make -j $NJOBS install-feelpp-base
    else
        echo "Feel++ source cannot be found. Please run pull_feelpp first."
    fi
}

# install_feelpp_base <NJOBS:1>
install_feelpp_base()
{
  build_feelpp_base ${1:-${DEFAULT_NJOBS}} ${*:2}
  clean_feelpp
}


#
# Feel++ module
configure_feelpp_module()
{
    exit_status=0
    echo "--- Configuring Feel++ $1 ..."
    cd $HOME
    cd ${FEELPP_BUILD_DIR}/
    if [[ $CXXFLAGS ]]; then
    	${FEELPP_SRC_DIR}/feelpp/configure -r --root="$2" --cxxflags="${CXXFLAGS}" --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} ${@:3}";
        ((exit_status= $exit_status || $?));
    else
        ${FEELPP_SRC_DIR}/feelpp/configure -r --root="$2" --cmakeflags="-DCMAKE_INSTALL_PREFIX=${FEELPP_HOME} ${@:3}";
        ((exit_status= $exit_status || $?));
    fi
    echo -e "\033[33;32m--- Configuring Feel++ $1 done. \033[0m"
    return $exit_status
}

build_feelpp_module()
{
    exit_status=0
    echo "--- Building Feel++ Module ${2}..."
    if [ -d ${FEELPP_SRC_DIR}/feelpp ]
    then
        MODULE=${2}
        echo $MODULE
        MODULEPATH=${3}
        echo $MODULEPATH
        # Get the number of jobs to be used
        NJOBS=${4:-${DEFAULT_NJOBS}}
        echo $NJOBS
        #shift
        # $* now contains possible additional cmake flags
        configure_feelpp_module ${MODULE} ${MODULEPATH} ${@:5}
        ((exit_status= $exit_status || $?));
        sudo make -j $NJOBS install
        ((exit_status= $exit_status || $?));
    else
        echo "Feel++ source cannot be found. Please run pull_feelpp first."
    fi
    echo -e "\033[33;32m--- Build Feel++ ${MODULE} done. \033[0m"
    return $exit_status
}

# install_feelpp_module <module name> <module path> options <NJOBS:1> <cmake flags>
install_feelpp_module()
{
    exit_status= 0
    build_feelpp_module ${1} ${2} ${3} ${4:-${DEFAULT_NJOBS}} ${*:5}
    ((exit_status= $exit_status || $?));
    clean_feelpp
    ((exit_status= $exit_status || $?));
    return $exit_status
}
