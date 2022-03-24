#!/bin/bash

DEFAULT_BRANCH=develop
DEFAULT_NJOBS=1

# set feelpp home
export FEELPP_SRC_DIR=${HOME}/src
mkdir -p ${FEELPP_SRC_DIR}

export FEELPP_BUILD_DIR=${FEELPP_SRC_DIR}/feelpp/build
mkdir -p ${FEELPP_BUILD_DIR}

export FEELPP_HOME=/usr/
mkdir -p ${FEELPP_HOME}

export PATH=${FEELPP_HOME}/bin:${PATH}
export LD_LIBRARY_PATH=${FEELPP_HOME}/lib:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=${FEELPP_HOME}/lib/pkgconfig:$PKG_CONFIG_PATH
export PYTHONPATH=${FEELPP_HOME}/lib/python3.8/site-packages:$PYTHONPATH
export PYTHONPATH=${FEELPP_HOME}/lib/python3.8/dist-packages:$PYTHONPATH
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
      git pull origin ${1:-${DEFAULT_BRANCH}}
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
      (cd applications/mesh && make -j $NJOBS && sudo make install )
      (cd applications/databases && make -j $NJOBS && sudo make install )
      (cd tools && make -j $NJOBS && sudo make install )
      #sudo make -j $NJOBS install-feelpp-lib
  else
      echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
clean_feelpp()
{
    for i in /usr/bin/feelpp*; do sudo strip $i; done
    for i in /usr/lib/libfeel*; do sudo strip $i; done
    sudo rm -rf ${FEELPP_BUILD_DIR}/*
    if test -d /feelpp/feelppdb/; then sudo rm -rf /feelpp/feelppdb/*; fi
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
    clean_feelpp
    ((exit_status= $exit_status || $?))
    return $exit_status
}

#
# Feel++ module
configure_feelpp_module()
{
    [[ ! -z $exit_status ]] && [ $exit_status -ne 0 ] && return $exit_status

    exit_status=0
    echo "--- Configuring ${3} Feel++ $1 ..."
    cd $HOME
    cd ${FEELPP_BUILD_DIR}/
    if [[ $CXXFLAGS ]]; then
    	#${FEELPP_SRC_DIR}/feelpp/configure ${3} --root="$2" --cxxflags="${CXXFLAGS}" --prefix="${FEELPP_HOME}" --cmakeflags="${@:4}";
        cmake --preset $2  -DCMAKE_INSTALL_PREFIX=/usr/ 
        ((exit_status= $exit_status || $?));
    else
        #${FEELPP_SRC_DIR}/feelpp/configure ${3} --root="$2" --prefix="${FEELPP_HOME}"  --cmakeflags="${@:4}";
        cmake --preset $2  -DCMAKE_INSTALL_PREFIX=/usr/
        ((exit_status= $exit_status || $?));
    fi
    echo -e "\033[33;32m--- Configuring Feel++ $1 done. \033[0m"
    return $exit_status
}

build_feelpp_module()
{
    [[ ! -z $exit_status ]] && [ $exit_status -ne 0 ] && return $exit_status

    exit_status=0
    echo "--- Building Feel++ Module ${2}..."
    if [ -d ${FEELPP_SRC_DIR}/feelpp ]
    then
        cd ${FEELPP_SRC_DIR}/feelpp
        MODULE="${2}"
        echo $MODULE
        MODULEPATH="${3}"
        echo $MODULEPATH
        # Get the number of jobs to be used
        NJOBS="${4:-${DEFAULT_NJOBS}}"
        echo $NJOBS
        #shift
        # $* now contains possible additional cmake flags
        test ! -z "${BUILDKITE_JOB_ID}" && buildkite-agent annotate "configure_feelpp_module ${MODULE} ${MODULEPATH} ${5} ${@:6}"
        #configure_feelpp_module "${MODULE}" "${MODULEPATH}" "${5}" "${@:6}"
        cmake --preset ${MODULE} -DCMAKE_INSTALL_PREFIX=/usr
        ((exit_status=$exit_status || $?));

        [[ ! -z $exit_status ]] && [ $exit_status -ne 0 ] && return $exit_status
        #sudo make -j $NJOBS install
        sudo cmake --build --preset ${MODULE} -j $NJOBS 
        ((exit_status=$exit_status || $?));
    else
        echo "Feel++ source cannot be found. Please run pull_feelpp first."
    fi
    echo -e "\033[33;32m--- Build Feel++ ${MODULE} done. \033[0m"
    return $exit_status
}

# <module name> <module path> <jobs>
ctest_feelpp_module()
{
    [[ ! -z $exit_status ]] && [ $exit_status -ne 0 ] && return $exit_status

    exit_status=0
    echo "--- CTesting Feel++ Module ${2}..."
    if [ -d ${FEELPP_SRC_DIR}/feelpp ]
    then
        CTEST_FLAGS="${3}"
        test ! -z "${BUILDKITE_JOB_ID}" && buildkite-agent annotate "running ctest ${CTEST_FLAGS}"
        #ctest ${CTEST_FLAGS}
        ctest --preset $2 -R feelpp 
        status=$?
#        if (( status != 0 )); then
          # ctest  --preset $2 -R feelpp
#        fi
        ((exit_status=$exit_status || $status));
        
        # if not empty then upload testsuite results
        if ! test -z "${BUILDKITE_JOB_ID}"; then
            xsltproc /usr/local/share/xsltproc/ctest-to-junit.xsl Testing/*/Test.xml > Testing/junit-${2}.xml
            buildkite-agent artifact upload "Testing/junit-*.xml"
        fi
    else
        echo "Feel++ source cannot be found. Please run pull_feelpp first then build_feelpp_module"
    fi
    echo -e "\033[33;32m--- CTesting Feel++ Module ${2} done. \033[0m"
    return $exit_status
}

# install_feelpp_module <module name> <module path> options <NJOBS:1> <cmake flags>
install_feelpp_module()
{
    exit_status=0
    if [ ! -d ${FEELPP_SRC_DIR}/feelpp ]; then
        echo "--- [install_feelpp_module ] Cloning feelpp..."
        BRANCH="${1:-${DEFAULT_BRANCH}}"
        pull_feelpp "${BRANCH}"
        ((exit_status= $exit_status || $?))
    elif test -d ${FEELPP_SRC_DIR}/feelpp/.git; then
        echo "--- [install_feelpp_module ] Pulling feelpp..."
        (${FEELPP_SRC_DIR}/feelpp/ && git pull)
    else
        echo "--- [install_feelpp_module ] Cloning feelpp..."
        BRANCH="${1:-${DEFAULT_BRANCH}}"
        pull_feelpp "${BRANCH}"
        ((exit_status= $exit_status || $?))
    fi
    exit_status=0
    build_feelpp_module "${1}" "${2}" "${3}" "${4:-${DEFAULT_NJOBS}}" "${5}" "${*:7}"
    ((exit_status=$exit_status || $?));
    ctest_feelpp_module "${1}" "${2}" "${6}"
    ((exit_status=$exit_status || $?));
    clean_feelpp
    ((exit_status=$exit_status || $?));
    return $exit_status
}
install_test_feelpp_module()
{
    NJOBS_TESTS=4
    exit_status=0
    build_feelpp_module "${1}" "${2}" "${3}" "${4:-${DEFAULT_NJOBS}}" "${5}" "${*:7}"
    ((exit_status=$exit_status || $?));
    ctest_feelpp_module "${1}" "${2}" "${6}"
    ((exit_status=$exit_status || $?));
    clean_feelpp
    ((exit_status=$exit_status || $?));
    return $exit_status
}
clean_feelpp_cpp_o()
{
    sudo find ${FEELPP_BUILD_DIR}/* -name "*.cpp.o" | xargs rm -f
}

install_test_feelpp_module_nofail()
{
    NJOBS_TESTS=4
    exit_status=0
    pull_feelpp ${1:-${DEFAULT_BRANCH}}
    build_feelpp_module "${1}" "${2}" "${3}" "${4:-${DEFAULT_NJOBS}}" "${5}" "${*:7}"
    ctest_feelpp_module "${1}" "${2}" "${6}"
    clean_feelpp_cpp_o
    return $exit_status
}
