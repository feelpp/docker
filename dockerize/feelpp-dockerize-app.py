#!/usr/bin/env python

import argparse
import errno
import shutil
import subprocess
import time
import os

debug = 0

# execute a command line
def executeCommand(text, cmd):
    out = ""
    returnCode = 0

    if(debug > 0):
        print cmd

    # Log execution time
    tstart = time.time()
    try:
        # Launch the current command and also redirect its output to log files
        out = subprocess.Popen(cmd.split(' '))
        out.communicate()
    except subprocess.CalledProcessError, e:
        out = e.output
        ret = e.returncode
    # Log execution time
    tend = time.time()
    tFinal = (tend - tstart)

    return returnCode, tFinal

# make a directory (don't fail if it exists)
def makedir(path):
    try:
        os.makedirs(path)
    except OSError as exc:
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else: raise

def writeCMakeLists(fpath, src, cfg, geo, defs):
    fl = open(fpath, "w")

    # Write header
    fl.write("""
cmake_minimum_required(VERSION 2.8)

# This will check for the installed Feel++ library
# If you did not install it in a standard system path,
# you need to specify the FEELPP_DIR variable to the root
# of your installation directory or add the path of your
# installation in the PATHS section
if ( ${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_CURRENT_SOURCE_DIR} )
    find_package(Feel++
        PATHS $ENV{FEELPP_DIR}/share/feel/cmake/modules
        /usr/share/feel/cmake/modules
        /usr/local/share/feel/cmake/modules
        /opt/share/feel/cmake/modules
    )
    if(NOT FEELPP_FOUND)
        message(FATAL_ERROR "Feel++ was not found on your system. Make sure to install it and specify the FEELPP_DIR to reference the installation directory.")
    endif()
endif()
    """)

    # Generate app build info
    fl.write("""
# Then you can add your application and the associated hpp, cpp, geo, msh and cfg files
feelpp_add_application(
    app """)
    fl.write("""
    SRCS """ + src
    )
    # Use geo if present
    if(geo != ""):
        fl.write("""
    GEO """ + os.path.basename(geo)
        )
    # Use cfg if present
    if(cfg != ""):
        fl.write("""
    CFG """ + os.path.basename(cfg)
        )
    if(defs != ""):
        fl.write("""
        DEFS """ + defs
        )
    fl.write("""
    )
    """)

    fl.close()

def writeDockerfile(fpath):
    fl = open(fpath, "w")

    # Write header
    fl.write("""
FROM feelpp/develop:insitu
MAINTAINER Feel++ Support <support@feelpp.org>

USER feelpp
ENV HOME /home/feelpp

RUN mkdir -p $HOME/project/build
COPY ./* $HOME/project/

# Install Feel++
WORKDIR $HOME/project/build
RUN bash -c " \\
    source $HOME/feelpp.conf.sh \\
    && cmake $HOME/project \\
    && make \\
    "

# COPY WELCOME $HOME/WELCOME
USER root
ENTRYPOINT ["/sbin/my_init","--quiet","--","sudo","-u","feelpp","/bin/sh","-c"]
CMD ["/bin/bash"]
    """)

    fl.close()

def main():
    # Parse arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('--src', required=True, help='Path to the original input file in .mha format')
    parser.add_argument('--geo', default="", help='Path to the geo file to use')
    parser.add_argument('--cfg', default="", help='Path to the cfg file')
    parser.add_argument('--defs', default="", help='Custom definitions to use')
    args = parser.parse_args()

    # Create workdir
    workdir = "dockerize-workdir"
    makedir(workdir)
    os.chdir(workdir)

    # Get app info
    srcName = os.path.basename(args.src)
    appName, _ = os.path.splitext(srcName)
    cfgName = os.path.basename(args.cfg)
    geoName = os.path.basename(args.geo)

    # Copy files
    shutil.copy(args.src, ".")
    if(args.cfg != ""):
        shutil.copy(args.cfg, ".")
    if(args.geo != ""):
        shutil.copy(args.geo, ".")

    # Write
    writeCMakeLists("CMakeLists.txt", srcName, cfgName, geoName, args.defs)
    writeDockerfile("Dockerfile")

    # Get name of source file to tag
    cmd = "docker build -t feelpp/" + appName + " ."
    print cmd
    retcode, _ = executeCommand("", cmd)

#docker run -ti

main()
