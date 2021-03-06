#!/bin/bash

# Environment variables
#export PATH=${FEELPP_HOME}/bin:${PATH}
export LD_LIBRARY_PATH=${FEELPP_DEP_INSTALL_PREFIX}/lib:${FEELPP_DEP_INSTALL_PREFIX}/lib/paraview-5.4:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=${FEELPP_DEP_INSTALL_PREFIX}/lib/pkgconfig:$PKG_CONFIG_PATH
export PYTHONPATH=${FEELPP_DEP_INSTALL_PREFIX}/lib/python2.7/site-packages:$PYTHONPATH
export PYTHONPATH=${FEELPP_DEP_INSTALL_PREFIX}/lib/paraview-5.4/site-packages:$PYTHONPATH
export PYTHONPATH=${FEELPP_DEP_INSTALL_PREFIX}/lib/paraview-5.4/site-packages/vtk:$PYTHONPATH
export PYTHONPATH=$PYTHONPATH:/usr/local/lib/python3.5/dist-packages/:/usr/local/lib/python3.5/site-packages/
export MANPATH=${FEELPP_DEP_INSTALL_PREFIX}/share/man:$MANPATH
