#!/bin/bash

usage="
Usage:
  A script to install and run an Underworld 3 software stack in Gadi.
  Based on Julian and Tyagi's scripts

** To install **
Review script details: modules, paths, repository urls / branches etc.
 $ source <this_script_name>
 $ install_full_stack

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

module purge
module load openmpi/4.1.4 hdf5/1.12.2p python3/3.11.0 gmsh/4.4.1 cmake

export GROUP=el06
export USER=jg0883
export INSTALL_NAME=Underworld3_0.9

# Louis' branch: boundary_integrals
GIT_COMMAND="git clone --branch boundary_integrals --depth 1 https://github.com/underworldcode/underworld3.git"

export USER_HOME=/home/157/jg0883/
export CODES_PATH=/scratch/$GROUP/$USER/codes/
export UW_OPT_DIR=$CODES_PATH/opt
export INSTALL_PATH=$CODES_PATH/$INSTALL_NAME

export OPENBLAS_NUM_THREADS=1 # disable numpy interal parallelisation
export OMPI_MCA_io=ompio    # preferred MPI IO implementation

export CDIR=$PWD

export PETSC_VERSION="main"
export PYTHONPATH=$CODES_PATH/petsc-${PETSC_VERSION}/arch-linux-c-opt/lib:$PYTHONPATH # set for petsc4py usage
#export PYTHONPATH=$UW_OPT_DIR/petsc-lm-${PETSC_VERSION}/lib:$PYTHONPATH
export PETSC_DIR=$CODES_PATH/petsc-${PETSC_VERSION} # do not set prefix to separate dir for now
#export PETSC_DIR=$UW_OPT_DIR/petsc-lm-${PETSC_VERSION}
export PETSC_ARCH=arch-linux-c-opt
export PYTHONPATH=$INSTALL_PATH/lib/python3.11/site-packages:${PYTHONPATH} # is this needed?


install_python_dependencies(){
	source $INSTALL_PATH/bin/activate
    pip3 install --upgrade pip==23.0 --no-binary :all:
	pip3 install --upgrade --force-reinstall --no-cache-dir cython
    pip3 install --no-binary :all: --no-cache-dir mpi4py
	pip3 install --no-cache-dir pytest
    pip3 install --upgrade --force-reinstall --no-cache-dir typing-extensions
    export HDF5_VERSION=1.12.2
    HDF5_MPI="ON" pip3 install --no-binary :all: --no-cache-dir h5py
}


install_petsc(){
	source $INSTALL_PATH/bin/activate

	cd $CODES_PATH
	wget https://gitlab.com/lmoresi/petsc/-/archive/main/petsc-${PETSC_VERSION}.tar.gz --no-check-certificate \
	&& tar -zxf petsc-${PETSC_VERSION}.tar.gz
	cd $CODES_PATH/petsc-${PETSC_VERSION}

    # for now, do not set prefix to a separate directory
	# install petsc
    #--prefix=$UW_OPT_DIR/petsc-lm-${PETSC_VERSION}\
	./configure --with-debugging=0                  \
		            --COPTFLAGS="-g -O3" --CXXOPTFLAGS="-g -O3" --FOPTFLAGS="-g -O3" \
		            --with-petsc4py=1               \
		            --with-zlib=1                   \
		            --with-shared-libraries=1       \
		            --with-cxx-dialect=C++11        \
		            --with-make-np=4                \
                    --with-hdf5-dir=$HDF5_DIR       \
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
		            --useThreads=0                  \
	&& make PETSC_DIR=`pwd` PETSC_ARCH=arch-linux-c-opt all    #\
	#&& make PETSC_DIR=`pwd` PETSC_ARCH=arch-linux-c-opt install

    cd $CDIR


}

install_underworld3(){
	source $INSTALL_PATH/bin/activate

	${GIT_COMMAND} $USER_HOME/uw3 \
	&& cd $USER_HOME/uw3 \
	&& ./clean.sh \
	&& python3 setup.py develop
    source pypathsetup.sh
	python3 -m pytest -v

	cd $CDIR
}

check_openmpi_exists(){
    source $INSTALL_PATH/bin/activate
    return $(python3 -c "from mpi4py import MPI")
}

check_petsc_exists(){
    source $INSTALL_PATH/bin/activate
    return $(python3 -c "from petsc4py import PETSc")
}

check_underworld3_exists(){
    source $INSTALL_PATH/bin/activate
    return $(python3 -c "import underworld3")
}


install_full_stack(){

    install_python_dependencies

    if ! check_petsc_exists; then
        install_petsc
    fi

    if ! check_underworld3_exists; then
        install_underworld3
    fi
}

if [ ! -d "$INSTALL_PATH" ]
then
    echo "Environment not found, creating a new one"
    mkdir -p $INSTALL_PATH
    python3 --version
    python3 -m venv --system-site-packages $INSTALL_PATH
else
    echo "Found Environment"
    source $INSTALL_PATH/bin/activate
fi
