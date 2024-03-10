#!/bin/zsh

usage="
Usage:
  A script to install and run an Underworld3 software stack.
  Change the directories accordingly when line comment says '# user_input'.
  Uses python 3.11 and open MPI 4.1.2 (to update).

** To install **
Review script details: modules, paths, repository urls / branches etc.
 $ source <this_script_name>
 $ install_full_stack

N.B.: Can also run steps individually as follows:
1. install_python_dependencies
2. install_petsc
3. install_h5py
4. install_underworld3


** To run **
source this file to open the environment
"

while getopts ':h' option; do
  case "$option" in
    h) echo "$usage"
       # safe script exit for sourced script
       (return 0 2>/dev/null) && return 0 || exit 0
       ;;
    \?) # incorrect options
       echo "Error: Incorrect options"
       echo "$usage"
       (return 0 2>/dev/null) && return 0 || exit 0
       ;;
  esac
done

module load python/3.11.7 openmpi/4.1.2
export OPENBLAS_NUM_THREADS=1 # not sure if this is needed
export OMPI_MCA_io=ompio      # not sure if this is needed

PYVER="3.11"
GIT_COMMAND="git clone --branch development --depth 1 https://github.com/underworldcode/underworld3.git"

# need to edit especially the USER_HOME
export USER_HOME=/home/juan                             # user_input
export INSTALL_PATH=$USER_HOME/uw3-local-installation
export INSTALL_NAME=uw3-venv-ompi-module                # user_input
export UW3_NAME=uw3-run

export ENV_PATH=${INSTALL_PATH}/${INSTALL_NAME}
export PKG_PATH=${INSTALL_PATH}/manual-install-pkg      # user_input
export PETSC_INSTALL=$PKG_PATH/petsc-main-ompi-module   # user_input

export CDIR=$PWD

# for kaiju, temporarily use the already installed openmpi
# 08/03/2024 - tried to install from source, but got mpi errors during run
#install_openmpi(){
#		# Build options for openmpi
#		OMPI_MAJOR_VERSION="v4.1"
#		OMPI_VERSION="4.1.6"
#		OMPI_CONFIGURE_OPTIONS="CC=gcc CXX=g++ FC=gfortran"
#		#OMPI_CONFIGURE_OPTIONS="CC=gcc CXX=g++ FC=gfortran --prefix=$PKG_PATH/openmpi-${OMPI_VERSION}"
#		OMPI_MAKE_OPTIONS="-j4"
#
#		# build mpi and remove tarball at the end
#		mkdir -p $INSTALL_PATH/tmp/src
#		cd $INSTALL_PATH/tmp/src
#		wget https://download.open-mpi.org/release/open-mpi/${OMPI_MAJOR_VERSION}/openmpi-${OMPI_VERSION}.tar.gz --no-check-certificate \
#		&& tar -zxf openmpi-${OMPI_VERSION}.tar.gz
#		cd $INSTALL_PATH/tmp/src/openmpi-${OMPI_VERSION}
#		./configure CC=gcc                                      \
#                    CXX=g++                                     \
#                    FC=gfortran                                 \
#                    --prefix=$PKG_PATH/openmpi-${OMPI_VERSION}  \
#		&&  make ${OMPI_MAKE_OPTIONS} \
#		&&  make install \
#		&&  rm -rf $INSTALL_PATH/tmp/src/
#
#		# add bin path to .zshrc file
#		echo "export PATH=\"$PKG_PATH/openmpi-${OMPI_VERSION}/bin:\$PATH\"" >> ~/.bash_profile
#		source ~/.bash_profile
#
#		cd $CDIR
#}

install_python_dependencies(){
		source ${ENV_PATH}/bin/activate
		pip3 install --upgrade pip
	    pip3 install --no-cache-dir trame trame-vuetify trame-vtk pyvista ipywidgets nest_asyncio
	    pip3 install --no-cache-dir ipython jupyterlab jupytext
		pip3 install --upgrade --force-reinstall --no-cache-dir cython
		pip3 install --no-binary :all: --no-cache-dir numpy
		pip3 install --no-binary :all: --no-cache-dir mpi4py
		pip3 install --upgrade --no-cache-dir gmsh
        pip3 install --upgrade mpmath==1.3.0
        pip3 install --upgrade --force-reinstall --no-cache-dir typing-extensions
		#pip3 install --no-binary :all: --upgrade --no-cache-dir gmsh # why does this not work?!
}

install_petsc(){

		source ${ENV_PATH}/bin/activate
		mkdir -p $PETSC_INSTALL
		mkdir -p $INSTALL_PATH/tmp/src
		cd $INSTALL_PATH/tmp/src
		PETSC_VERSION="main"
		wget https://gitlab.com/petsc/petsc/-/archive/main/petsc-${PETSC_VERSION}.tar.gz --no-check-certificate \
		&& tar -zxf petsc-${PETSC_VERSION}.tar.gz
		cd $INSTALL_PATH/tmp/src/petsc-${PETSC_VERSION}
        PETSC_DIR=`pwd`

		# install petsc
		./configure --with-debugging=0 --prefix=$PETSC_INSTALL \
		            --COPTFLAGS="-g -O3" --CXXOPTFLAGS="-g -O3" --FOPTFLAGS="-g -O3" \
		            --with-petsc4py=1               \
		            --with-zlib=1                   \
		            --with-shared-libraries=1       \
		            --with-cxx-dialect=C++11        \
		            --with-make-np=4                \
		            --download-cmake=1			    \
		            --download-zlib=1			    \
		            --download-hdf5=1               \
		            --download-mumps=1              \
		            --download-parmetis=1           \
		            --download-metis=1              \
		            --download-superlu=1            \
		            --download-hypre=1              \
		            --download-scalapack=1          \
		            --download-superlu_dist=1       \
		            --download-pragmatic=1          \
		            --download-ctetgen              \
		            --download-eigen                \
		            --download-superlu=1            \
		            --download-triangle             \
                    --download-fblaslapack=1        \
		            --useThreads=0                  \
		&& make PETSC_DIR=`pwd` PETSC_ARCH=arch-linux-c-opt all \
		&& make PETSC_DIR=`pwd` PETSC_ARCH=arch-linux-c-opt install \
		&& rm -rf $INSTALL_PATH/tmp/src

		# add bin path to .zshrc file
		echo "export PYTHONPATH=\"$PETSC_INSTALL/lib:\$PYTHONPATH\"" >> ~/.bash_profile
		echo "export PETSC_DIR=$PETSC_INSTALL" >> ~/.bash_profile
		echo "export PETSC_ARCH=arch-linux-c-opt" >> ~/.bash_profile
		source ~/.bash_profile

		cd $CDIR
}
install_h5py(){
		source ${ENV_PATH}/bin/activate
		CC=mpicc HDF5_MPI="ON" HDF5_DIR=$PETSC_DIR pip3 install --no-cache-dir --no-binary=h5py h5py
		pip3 install --no-cache-dir pytest
}

install_underworld3(){
		source ${ENV_PATH}/bin/activate

		$GIT_COMMAND ${INSTALL_PATH}/${UW3_NAME} \
		&& cd ${INSTALL_PATH}/${UW3_NAME} \
		&& ./clean.sh               \
		&& python3 setup.py develop
		python3 -m pytest -v

		cd $CDIR
}


check_openmpi_exists(){
        source ${ENV_PATH}/bin/activate
        return $(python${PYVER} -c "from mpi4py import MPI")
}

check_petsc_exists(){
        source ${ENV_PATH}/bin/activate
        return $(python${PYVER} -c "from petsc4py import PETSc")
}

check_underworld3_exists(){
        source ${ENV_PATH}/bin/activate
        return $(python${PYVER} -c "import underworld3")
}


install_full_stack(){


    install_python_dependencies

    if ! check_petsc_exists; then
        install_petsc
    fi

    install_h5py

    if ! check_underworld3_exists; then
        install_underworld3
    fi

}

if [ ! -d "$ENV_PATH" ]
then
    echo "Environment not found, creating a new one"
    mkdir -p $ENV_PATH
    python${PYVER} --version
    python${PYVER} -m venv --system-site-packages $ENV_PATH
else
    echo "Found Environment"
    source ${ENV_PATH}/bin/activate
fi
