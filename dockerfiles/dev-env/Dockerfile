FROM phusion/baseimage:latest
MAINTAINER Feel++ Support <support@feelpp.org>

ARG BUILD_JOBS=16
ARG INSTALL_OPENTURNS=1
ARG INSTALL_BOOST=1
ARG INSTALL_PETSC=1
ARG INSTALL_SLEPC=1
ARG INSTALL_GMSH=1
ARG INSTALL_PARAVIEW=1

RUN add-apt-repository ppa:ubuntu-toolchain-r/test
#RUN apt-add-repository 'deb http://llvm.org/apt/trusty/ llvm-toolchain-trusty-3.8 main'

# We don't have a command line available
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qq update && \
    apt-get -y --force-yes install \
         xauth cmake flex gcc-4.9 g++-4.9 gfortran git subversion ipython openmpi-bin pkg-config \
         wget bison sudo \
         libgmp-dev libmpfr-dev libmpc-dev \
         libbz2-dev libncurses-dev \
         automake autoconf libtool \
         libopenblas-dev libcln-dev libcppunit-dev \
         libeigen3-dev liblapack-dev libmpfr-dev \
         libopenmpi-dev libann-dev libglpk-dev \
         python-dev libhwloc-dev libvtk6-dev libpcre3-dev \
         libhdf5-openmpi-dev libeigen3-dev libcgal-dev \
         python-numpy python-vtk6 python-six python-ply \
         python-h5py python-urllib3 xterm tmux screen \
    && if [ x$INSTALL_PARAVIEW = x1 ]; then \
    apt-get -y --force-yes install libphonon-dev libphonon4 qt4-dev-tools libqt4-core libqt4-gui qt4-qmake libxt-dev libqt4-opengl-dev mesa-common-dev \
    ; fi \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 10 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.8 10 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 20 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.9 20 \
    && update-alternatives --set gcc "/usr/bin/gcc-4.9" \
    && update-alternatives --set g++ "/usr/bin/g++-4.9" \
    && update-alternatives --set cc /usr/bin/gcc \
    && update-alternatives --set c++ /usr/bin/g++ \
    && apt-get autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# C++
ENV FEELPP_DEP_INSTALL_PREFIX /usr/local

# Export environment variables for the whole dependencies
ENV PATH ${FEELPP_DEP_INSTALL_PREFIX}/bin:${PATH}
ENV LD_LIBRARY_PATH ${FEELPP_DEP_INSTALL_PREFIX}/lib:${FEELPP_DEP_INSTALL_PREFIX}/lib64:${LD_LIBRARY_PATH}
ENV MANPATH ${FEELPP_DEP_INSTALL_PREFIX}/share/man:${MANPATH}
ENV CMAKE_PREFIX_PATH ${FEELPP_DEP_INSTALL_PREFIX}:${CMAKE_PREFIX_PATH}

# CMake (Version >= 3.5 needed for clang and ParaView)
ENV CMAKE_VERSION 3.6.1
RUN cd /tmp \
    && wget https://cmake.org/files/v3.6/cmake-${CMAKE_VERSION}.tar.gz \
    && tar zxvf cmake-${CMAKE_VERSION}.tar.gz \
    && mkdir cmake-${CMAKE_VERSION}-build && cd cmake-${CMAKE_VERSION}-build \
    && ../cmake-${CMAKE_VERSION}/configure --prefix=${FEELPP_DEP_INSTALL_PREFIX} \
    && make -j ${BUILD_JOBS} \
    && make install \
    && rm -rf /tmp/*

# GCC
ENV GCC_VERSION 6.1.0
RUN cd /tmp \
    && wget http://fr.mirror.babylon.network/gcc/releases/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz \
    && tar zxvf gcc-${GCC_VERSION}.tar.gz \
    && mkdir gcc-${GCC_VERSION}-build && cd gcc-${GCC_VERSION}-build \
    && ../gcc-${GCC_VERSION}/configure --prefix=${FEELPP_DEP_INSTALL_PREFIX} \
         --enable-bootstrap \
         --enable-shared \
         --enable-threads=posix \
         --enable-checking=release \
         --with-system-zlib \
         --enable-__cxa_atexit \
         --disable-libunwind-exceptions \
         --enable-gnu-unique-object \
         --enable-languages=c,c++,fortran \
         --disable-dssi \
         --with-ppl \
         --with-cloog \
         --with-tune=generic \
         --disable-multilib \
         --with-arch_32=i686
RUN cd /tmp/gcc-${GCC_VERSION}-build && make -j ${BUILD_JOBS}
RUN cd /tmp/gcc-${GCC_VERSION}-build && make install \
    && rm -rf /tmp/* \

RUN gcc --version

# Clang
RUN cd tmp \
    && git clone http://llvm.org/git/llvm.git llvm && cd llvm && git checkout refs/remotes/origin/release_39 && cd .. \
    && cd llvm/tools && git clone http://llvm.org/git/clang.git clang && cd clang && git checkout refs/remotes/origin/release_39 && cd .. \
    && cd ../.. \
    && cd llvm/projects && git clone http://llvm.org/git/compiler-rt.git && cd compiler-rt && git checkout refs/remotes/origin/release_39 && cd .. \
    && git clone http://llvm.org/git/openmp.git && cd openmp && git checkout refs/remotes/origin/release_39 && cd .. \
    && cd ../.. \
    && mkdir llvm-svn-build && cd llvm-svn-build

RUN cd /tmp/llvm-svn-build && cmake /tmp/llvm \
 -DCMAKE_BUILD_TYPE=Release -DGCC_INSTALL_PREFIX=${FEELPP_DEP_INSTALL_PREFIX} \
 -DCMAKE_C_COMPILER=${FEELPP_DEP_INSTALL_PREFIX}/bin/gcc -DCMAKE_CXX_COMPILER=${FEELPP_DEP_INSTALL_PREFIX}/bin/g++ \
 -DBUILD_SHARED_LIBS=ON -DLLVM_BUILD_TOOLS=OFF -DCLANG_INCLUDE_DOCS=OFF -DCLANG_INCLUDE_TESTS=OFF \
 -DCMAKE_INSTALL_PREFIX=${FEELPP_DEP_INSTALL_PREFIX}
RUN cd /tmp/llvm-svn-build && make -j 24
RUN cd /tmp/llvm-svn-build && make install \
    && rm -rf /tmp/*

# Set main compiler to clang from now on
ENV CC ${FEELPP_DEP_INSTALL_PREFIX}/bin/clang
ENV CXX ${FEELPP_DEP_INSTALL_PREFIX}/bin/clang++

RUN clang --version

# Openturns
RUN if [ x$INSTALL_OPENTURNS = x1 ]; then \
    curl http://ubuntu.openturns.org/openturns.org-repo.key | apt-key add - \
    && apt-add-repository 'deb http://ubuntu.openturns.org trusty main' \
    && apt-get -qq update \
    && apt-get -y --force-yes install python-openturns \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    ; fi

# Boost
ENV BOOST_VERSION 1.61.0
ENV BOOST_DIR boost_1_61_0
RUN if [ x$INSTALL_BOOST = x1 ]; then \
    cd /tmp \
    && wget http://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/${BOOST_DIR}.tar.bz2/download -O ${BOOST_DIR}.tar.bz2 \
    && tar xjf ${BOOST_DIR}.tar.bz2 \
    && cd ${BOOST_DIR} \
    && echo "using mpi ;" >> user-config.jam \
    && echo "" >> user-config.jam \
    && ./bootstrap.sh \
    && ./bjam -j${BUILD_JOBS} install \
      --layout=tagged \
      --prefix=${FEELPP_DEP_INSTALL_PREFIX} \
      --user-config=user-config.jam \
      variant=release \
      threading=multi \
      link=shared \
    && rm -rf /tmp/* \
    ; fi

# Set BOOST ROOT
ENV BOOSTROOT ${FEELPP_DEP_INSTALL_PREFIX}

# Install PETSc from source
ENV PETSC_VERSION 3.7.3
RUN if [ x$INSTALL_PETSC = x1 ]; then \
    cd /tmp \
    && wget -nc http://ftp.mcs.anl.gov/pub/petsc/release-snapshots/petsc-${PETSC_VERSION}.tar.gz \
    && tar -xf petsc-${PETSC_VERSION}.tar.gz \
    && cd petsc-${PETSC_VERSION} \
    && ./configure \
                --COPTFLAGS="-O3" \ --CXXOPTFLAGS="-O3" \ --FOPTFLAGS="-O3" \
                --with-blas-lib=/usr/lib/libopenblas.a --with-lapack-lib=/usr/lib/liblapack.a \
                --with-c-support \
                --with-debugging=0 \
                --with-shared-libraries=1 \
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
                --download-fftw=1 \
                --prefix=${FEELPP_DEP_INSTALL_PREFIX} \
     && make \
     && make install \
     && rm -rf /tmp/* \
     ; fi

ENV PETSC_DIR ${FEELPP_DEP_INSTALL_PREFIX}

# Install SLEPc from source
ENV SLEPC_VERSION 3.7.2
RUN if [ x$INSTALL_SLEPC = x1 ]; then \
    cd /tmp \
    && export PETSC_DIR=${FEELPP_DEP_INSTALL_PREFIX} \
    && wget -nc http://www.grycap.upv.es/slepc/download/download.php?filename=slepc-${SLEPC_VERSION}.tar.gz -O slepc-${SLEPC_VERSION}.tar.gz \
    && tar -xf slepc-${SLEPC_VERSION}.tar.gz \
    && cd slepc-${SLEPC_VERSION} \
    && ./configure --prefix=${FEELPP_DEP_INSTALL_PREFIX} \
    && make \
    && make install \
    && rm -rf /tmp/* \
    ; fi

ENV SLEPC_DIR ${FEELPP_DEP_INSTALL_PREFIX}

# Gmsh
# check to see if protobuf folder is empty
ENV GMSH_VERSION 2.13.2
RUN if [ x$INSTALL_GMSH = x1 ]; then \
    cd /tmp \
    && wget http://www.geuz.org/gmsh/src/gmsh-${GMSH_VERSION}-source.tgz \
    && tar xvzf gmsh-${GMSH_VERSION}-source.tgz \
    && cd gmsh-${GMSH_VERSION}-source \
    && mkdir build \
    && cd build \
    && cmake \
        -DCMAKE_CXX_COMPILER=${CXX} \
        -DCMAKE_C_COMPILER=${CC} \
        -DCMAKE_INSTALL_PREFIX=${FEELPP_DEP_INSTALL_PREFIX} \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_BUILD_LIB=ON \
        -DENABLE_BUILD_SHARED=ON \
        -DENABLE_BUILD_DYNAMIC=ON \
        -DENABLE_PETSC=OFF \
        -DENABLE_MPI=OFF \
        -DENABLE_MUMPS=OFF \
        -DENABLE_OPENMP=ON  \
        .. \
    && make -j${BUILD_JOBS} \
    && make install \
    && rm -rf /tmp/* \
    ; fi

ENV GMSH_DIR ${FEELPP_DEP_INSTALL_PREFIX}

# ParaView
ENV PARAVIEW_VERSION 5.1.0
RUN if [ x$INSTALL_PARAVIEW = x1 ]; then \
    cd /tmp \
    && wget "http://www.paraview.org/paraview-downloads/download.php?submit=Download&version=v5.1&type=source&os=all&downloadFile=ParaView-v${PARAVIEW_VERSION}.tar.gz" -O ParaView-v${PARAVIEW_VERSION}.tar.gz \
    && tar xvzf ParaView-v${PARAVIEW_VERSION}.tar.gz \
    && cd ParaView-v${PARAVIEW_VERSION} \
    && mkdir build \
    && cd build \
    && cmake \
        -DBUILD_TESTING=OFF \
        -DCMAKE_CXX_COMPILER=${CXX} \
        -DCMAKE_C_COMPILER=${CC} \
        -DCMAKE_INSTALL_PREFIX=${FEELPP_DEP_INSTALL_PREFIX} \
        -DCMAKE_BUILD_TYPE=Release \
        -DPARAVIEW_BUILD_QT_GUI=ON \
        -DPARAVIEW_ENABLE_CATALYST=ON \
        -DPARAVIEW_ENABLE_PYTHON=ON \
        -DPARAVIEW_INSTALL_DEVELOPMENT_FILES=ON \
        -DPARAVIEW_USE_MPI=ON \
        -DVTK_RENDERING_BACKEND=OpenGL \
        .. \
    && make -j ${BUILD_JOBS} \
    && make install \
    && rm -rf /tmp/* \
    ; fi

ENV LD_LIBRARY_PATH ${FEELPP_DEP_INSTALL_PREFIX}/lib/paraview-5.1
ENV PYTHONPATH ${FEELPP_DEP_INSTALL_PREFIX}/lib/paraview-5.1/site-packages

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
