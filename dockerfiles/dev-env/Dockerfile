
FROM phusion/baseimage:0.9.17
MAINTAINER Feel++ Support <support@feelpp.org>


# Install build environment
RUN apt-add-repository 'deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu trusty main'
RUN apt-add-repository 'deb http://llvm.org/apt/trusty/ llvm-toolchain-trusty-3.7 main'

RUN apt-get -qq update && \
    apt-get -y --force-yes install \
    	 xauth cmake flex g++-4.9 clang-3.7 gfortran git ipython openmpi-bin pkg-config \
         wget bison sudo \
         libbz2-dev \
         automake autoconf libtool \
         libopenblas-dev libcln-dev libcppunit-dev \
         libeigen3-dev liblapack-dev libmpfr-dev \
         libopenmpi-dev libann-dev libglpk-dev \
         python-dev libhwloc-dev libvtk6-dev libpcre3-dev \
         libhdf5-openmpi-dev libeigen3-dev libcgal-dev \
         python-numpy python-vtk6 python-six python-ply \
         python-h5py python-urllib3 xterm tmux screen && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# C++
ENV CXX clang++-3.7 
ENV CC clang-3.7
ENV FEELPP_DEP_INSTALL_PREFIX /usr/local

# Boost
ENV BOOST_VERSION 1.59.0 
ENV BOOST_DIR boost_1_59_0
RUN wget http://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/${BOOST_DIR}.tar.bz2/download -O ${BOOST_DIR}.tar.bz2 \
    && tar xjf ${BOOST_DIR}.tar.bz2 \
    && cd ${BOOST_DIR} \
    && echo "using mpi ;" >> user-config.jam \
    && echo "" >> user-config.jam \
    && ./bootstrap.sh \
    && ./bjam -j4 install \
      --layout=tagged \
      --prefix=${FEELPP_DEP_INSTALL_PREFIX} \
      --user-config=user-config.jam \
      variant=release \
      threading=multi \
      link=shared

# Install PETSc from source
ENV PETSC_VERSION 3.6.3
RUN cd /tmp && \
    wget -nc http://ftp.mcs.anl.gov/pub/petsc/release-snapshots/petsc-${PETSC_VERSION}.tar.gz && \
    tar -xf petsc-${PETSC_VERSION}.tar.gz && \
    cd petsc-${PETSC_VERSION} && \
    ./configure --COPTFLAGS="-O2" \
                --CXXOPTFLAGS="-O2" \
                --FOPTFLAGS="-O2" \
                --with-blas-lib=/usr/lib/libopenblas.a --with-lapack-lib=/usr/lib/liblapack.a \
                --with-c-support \
                --with-debugging=0 \
                --with-shared-libraries \
                --download-suitesparse \
                --download-scalapack \
                --download-metis \
                --download-parmetis \
                --download-ptscotch \
                --download-hypre \
                --download-mumps \
                --download-blacs \
                --download-spai \
                --download-ml \
                --prefix=${FEELPP_DEP_INSTALL_PREFIX} && \
     make && \
     make install && \
     rm -rf /tmp/*

# Install SLEPc from source
ENV SLEPC_VERSION 3.6.3
RUN cd /tmp && \
    export PETSC_DIR=${FEELPP_DEP_INSTALL_PREFIX} && \
    wget -nc http://www.grycap.upv.es/slepc/download/download.php?filename=slepc-${SLEPC_VERSION}.tar.gz -O slepc-${SLEPC_VERSION}.tar.gz && \
    tar -xf slepc-${SLEPC_VERSION}.tar.gz && \
    cd slepc-${SLEPC_VERSION} && \
    ./configure --prefix=${FEELPP_DEP_INSTALL_PREFIX} && \
    make && \
    make install && \
    rm -rf /tmp/*

ENV SLEPC_DIR ${FEELPP_DEP_INSTALL_PREFIX}
ENV PETSC_DIR ${FEELPP_DEP_INSTALL_PREFIX}

# Gmsh
# check to see if protobuf folder is empty
ENV GMSH_VERSION 2.10.1
RUN cd /tmp \
    && wget http://www.geuz.org/gmsh/src/gmsh-${GMSH_VERSION}-source.tgz \
    && tar xvzf gmsh-${GMSH_VERSION}-source.tgz \
    && cd gmsh-${GMSH_VERSION}-source \
    && mkdir build \
    && cd build \
    && cmake \
        -DCMAKE_CXX_COMPILER=${CXX} \
        -DCMAKE_C_COMPILER=${CC} \
        -DCMAKE_INSTALL_PREFIX=${FEELPP_DEP_INSTALL_PREFIX} \
        -DCMAKE_BUILD_TYPE=release \
        -DENABLE_BUILD_LIB=ON \
        -DENABLE_BUILD_SHARED=ON \
        -DENABLE_BUILD_DYNAMIC=ON \
        -DENABLE_MPI=OFF \
        -DENABLE_MUMPS=OFF \
        -DENABLE_OPENMP=ON  \
        .. \
    && make -j4 \
    && make install \
    && rm -rf /tmp/*

# ParaView
ENV PARAVIEW_VERSION 4.4.0
RUN cd /tmp \
    && wget "http://www.paraview.org/paraview-downloads/download.php?submit=Download&version=v4.4&type=source&os=all&downloadFile=ParaView-v${PARAVIEW_VERSION}-source.tar.gz" -O ParaView-v${PARAVIEW_VERSION}-source.tar.gz \
    && tar xvzf ParaView-v${PARAVIEW_VERSION}-source.tar.gz \
    && cd ParaView-v${PARAVIEW_VERSION}-source \
    && mkdir build \
    && cd build \
    && cmake \
        -DCMAKE_CXX_COMPILER=${CXX} \
        -DCMAKE_C_COMPILER=${CC} \
        -DCMAKE_INSTALL_PREFIX=${FEELPP_DEP_INSTALL_PREFIX} \
        -DCMAKE_BUILD_TYPE=Release \
        -DPARAVIEW_BUILD_QT_GUI=OFF \
        -DPARAVIEW_ENABLE_CATALYST=ON \
        -DPARAVIEW_ENABLE_PYTHON=ON \
        -DPARAVIEW_INSTALL_DEVELOPMENT_FILES=ON \
        -DPARAVIEW_USE_MPI=ON \
        .. \
    && make -j8 \
    && make install \
    && rm -rf /tmp/*

# Set up user so that we do not run as root
# Changing the password does not work on certain OS and is not needed
# echo "feelpp:docker" | chpasswd && \
RUN useradd -m -s /bin/bash -G sudo,docker_env feelpp && \
    echo "feelpp ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# See https://github.com/phusion/baseimage-docker/issues/186
RUN touch /etc/service/syslog-forwarder/down

ENV HOME /home/feelpp

# Our helper script
COPY feelpp.env.sh $HOME/feelpp.env.sh
# and the README
COPY WELCOME $HOME/WELCOME
RUN chown feelpp:feelpp $HOME/WELCOME && \
    chown feelpp:feelpp $HOME/feelpp.env.sh && \
    chmod u+rw $HOME/WELCOME && \
    chmod u+rw $HOME/feelpp.env.sh

# OpenBLAS threads should be 1 to ensure performance
RUN echo "export OPENBLAS_NUM_THREADS=1" >> $HOME/.bashrc && \
    echo "export OPENBLAS_VERBOSE=0" >> $HOME/.bashrc

# This makes sure we launch with ENTRYPOINT /bin/bash into the home directory
RUN echo "export FEELPP_DEP_INSTALL_PREFIX=${FEELPP_DEP_INSTALL_PREFIX}" >> $HOME/.bashrc && \
    echo "export CC=$CC" >> $HOME/.bashrc && \
    echo "export CXX=$CXX" >> $HOME/.bashrc && \
    echo "source $HOME/feelpp.env.sh" >> $HOME/.bashrc && \
    echo "cd $HOME" >> $HOME/.bashrc && \
    echo "cat $HOME/WELCOME" >> $HOME/.bashrc

ENTRYPOINT ["/sbin/my_init","--quiet","--","sudo","-u","feelpp","/bin/sh","-c"]
CMD ["/bin/bash"]
