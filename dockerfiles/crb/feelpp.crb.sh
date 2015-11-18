#!/bin/bash

# bash functions
build_crb_app()
{
  echo "Building CRB applications..."
  if [ -d ${FEELPP_SRC_DIR}/feelpp ]
  then
        cd ${FEELPP_BUILD_DIR}/applications/crb
        sudo make -j 16
  else
	   echo "Feel++ source cannot be found. Please run pull_feelpp first."
  fi
}
