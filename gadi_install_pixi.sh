#!/bin/bash
#
# Underworld3 SHARED install script for NCI Gadi (pixi-based)
#
# Installs UW3 to /g/data/m18/software/uw3-pixi/ using pixi for Python
# package management. All group members in m18 can use this install.
#
# Gadi modules provide OpenMPI and HDF5; pixi (conda-forge) handles
# pure Python dependencies. mpi4py, PETSc, h5py built from source.
#
# Usage:
#   source gadi_install_pixi.sh         # activate shared environment
#   source gadi_install_pixi.sh install # full installation (first time only)
#
# NOTE: This script is designed to be sourced, NOT executed directly.
# Do NOT add 'set -e' here — it would cause your shell to close on any
# error since the script runs in your current shell.

usage="
Usage:
  A script to install and run an Underworld 3 software stack in Gadi (pixi).

** To activate existing install **
  \$ source <this_script_name>

** To install **
  Review script details: paths, modules, branch name, INSTALL_NAME (date).
  \$ source <this_script_name> install
"

while getopts ':h' option; do
  case "$option" in
    h) echo "$usage"
       (return 0 2>/dev/null) && return 0 || exit 0
       ;;
    \?)
       echo "Error: Incorrect options"
       echo "$usage"
       (return 0 2>/dev/null) && return 0 || exit 0
       ;;
  esac
done

# ============================================================
# CONFIGURATION — review before installing
# ============================================================

export UW3_BRANCH=development
#export UW3_REPO="https://github.com/underworldcode/underworld3.git"
export UW3_REPO="https://github.com/jcgraciosa/underworld3.git"


# DDMonYY naming convention — update this for each new install
export INSTALL_NAME=uw3-development-17Mar26

export BASE_PATH=/g/data/m18/software/uw3-pixi
export PIXI_HOME=$BASE_PATH/pixi          # pixi binary lives at $PIXI_HOME/bin/pixi
export UW3_PATH=$BASE_PATH/$INSTALL_NAME  # UW3 repo root IS this dated directory

# ============================================================
# DERIVED PATHS — do not edit below this line
# ============================================================

export PIXI_MANIFEST="${UW3_PATH}/pixi.toml"
export PETSC_DIR="${UW3_PATH}/petsc-custom/petsc"
export PETSC_ARCH=arch-linux-c-opt

export OPENBLAS_NUM_THREADS=1  # disable numpy internal parallelisation
export OMPI_MCA_io=ompio       # preferred MPI IO implementation

export CDIR=$PWD

# ============================================================
# ENVIRONMENT ACTIVATION
# Called automatically at script source time.
# ============================================================

load_env() {
    module purge
    module load openmpi/4.1.7 hdf5/1.12.2p gmsh/4.13.1 cmake/3.31.6

    export MPI_DIR
    MPI_DIR="$(dirname "$(dirname "$(which mpicc)")")"

    # Add pixi binary to PATH
    export PATH="${PIXI_HOME}/bin:${PATH}"

    # Activate pixi gadi environment
    if command -v pixi &>/dev/null && [ -f "${PIXI_MANIFEST}" ]; then
        if ! echo "${PATH}" | tr ':' '\n' | grep -q "\.pixi/envs/gadi/bin"; then
            eval "$(pixi shell-hook -e gadi --manifest-path "${PIXI_MANIFEST}")"
        fi
    fi

    # PETSc + petsc4py
    if [ -d "${PETSC_DIR}/${PETSC_ARCH}" ]; then
        export PYTHONPATH="${PETSC_DIR}/${PETSC_ARCH}/lib:${PYTHONPATH}"
    fi

    export OPENBLAS_NUM_THREADS=1
    export OMPI_MCA_io=ompio

    echo "==> Environment ready"
    echo "    MPI_DIR:    ${MPI_DIR}"
    echo "    HDF5_DIR:   ${HDF5_DIR}"
    echo "    UW3_PATH:   ${UW3_PATH}"
    echo "    PETSC_DIR:  ${PETSC_DIR}"
    echo "    PETSC_ARCH: ${PETSC_ARCH}"
}

# ============================================================
# INSTALLATION FUNCTIONS
# ============================================================

setup_pixi() {
    if command -v pixi &>/dev/null; then
        echo "==> pixi already installed: $(pixi --version)"
        return 0
    fi
    echo "==> Installing pixi to ${PIXI_HOME}..."
    mkdir -p "${PIXI_HOME}"
    curl -fsSL https://pixi.sh/install.sh | bash
    echo "==> pixi installed: $(pixi --version)"
}

clone_uw3() {
    if [ ! -d "${UW3_PATH}" ]; then
        echo "==> Cloning Underworld3 (branch: ${UW3_BRANCH}) to ${UW3_PATH}..."
        git clone --branch "${UW3_BRANCH}" --depth 1 "${UW3_REPO}" "${UW3_PATH}"
    else
        echo "==> Underworld3 source already present at ${UW3_PATH}"
    fi
}

install_pixi_env() {
    echo "==> Installing pixi gadi environment (~3 min)..."
    pixi install -e gadi --manifest-path "${PIXI_MANIFEST}"
    eval "$(pixi shell-hook -e gadi --manifest-path "${PIXI_MANIFEST}")"
    echo "==> pixi gadi environment ready"
}

install_mpi4py() {
    echo "==> Building mpi4py from source against Gadi OpenMPI..."
    pip install --no-binary :all: --no-cache-dir --force-reinstall "mpi4py>=4,<5"
    echo "==> mpi4py installed"
}

install_petsc() {
    echo "==> Building PETSc with AMR tools (~1 hour)..."
    bash "${UW3_PATH}/petsc-custom/build-petsc-gadi.sh"
    export PYTHONPATH="${PETSC_DIR}/${PETSC_ARCH}/lib:${PYTHONPATH}"
    echo "==> PETSc installed"
}

install_h5py() {
    echo "==> Building h5py against Gadi HDF5 module..."
    # Run in a subshell so the unsets don't affect the parent shell.
    # LIBRARY_PATH/CPATH are set by the pixi/conda activation and point to the
    # conda-forge HDF5 1.14 in the pixi env. If not unset, the linker picks up
    # conda's libhdf5.so.310 instead of Gadi's 1.12.2p, causing a symbol error
    # (H5E_BADATOM_g was removed in HDF5 1.14).
    # HDF5_VERSION: Gadi module string "1.12.2p" is unparseable by h5py — override.
    # Gadi's hdf5.h does not include H5FDmpio.h, so we force-include it via CFLAGS.
    (
        # Unset all conda compiler/linker env vars so they don't bleed into the
        # h5py build. In particular, conda's LDFLAGS embeds -L and -rpath for the
        # conda env lib dir, which causes the linker to pick up conda's
        # libhdf5.so.310 (HDF5 1.14) instead of Gadi's 1.12.2p.
        unset LDFLAGS LIBRARY_PATH CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH
        export LDFLAGS="-L${HDF5_DIR}/lib -Wl,-rpath,${HDF5_DIR}/lib"
        CC=mpicc \
        HDF5_MPI="ON" \
        HDF5_DIR="${HDF5_DIR}" \
        HDF5_VERSION="1.12.2" \
        CFLAGS="-I${HDF5_DIR}/include -include ${HDF5_DIR}/include/hdf5.h -include ${HDF5_DIR}/include/H5FDmpio.h" \
        pip install --no-binary=h5py --no-cache-dir --force-reinstall --no-deps h5py
    )
    echo "==> h5py installed"
}

install_uw3() {
    echo "==> Installing Underworld3..."
    cd "${UW3_PATH}"
    # --no-build-isolation: use the already-built petsc4py from PYTHONPATH
    # rather than letting pip download and rebuild it from PyPI in a fresh env.
    pip install --no-build-isolation -e .
    cd "${CDIR}"
    echo "==> Underworld3 installed"
}

fix_permissions() {
    echo "==> Setting shared read permissions on ${BASE_PATH}..."
    chmod -R a+rX "${BASE_PATH}"
    find "${BASE_PATH}" -type d -exec chmod a+x {} +
    # PETSc is on scratch (symlinked from gdata) — chmod doesn't follow symlinks
    # so we must set permissions on the real scratch path explicitly.
    local _real_petsc
    _real_petsc="$(readlink -f "${PETSC_DIR}")"
    if [ -d "${_real_petsc}" ] && [ "${_real_petsc}" != "${PETSC_DIR}" ]; then
        echo "==> Setting permissions on PETSc scratch path: ${_real_petsc}"
        chmod -R a+rX "${_real_petsc}"
        find "${_real_petsc}" -type d -exec chmod a+x {} +
    fi
    echo "==> Permissions set"
}

check_petsc_exists() {
    python3 -c "from petsc4py import PETSc" 2>/dev/null
}

check_uw3_exists() {
    python3 -c "import underworld3" 2>/dev/null
}

verify_install() {
    echo "==> Verifying installation..."
    python3 -c "
from mpi4py import MPI
print(f'mpi4py OK   — MPI version: {MPI.Get_version()}')
from petsc4py import PETSc
print(f'petsc4py OK — PETSc version: {PETSc.Sys.getVersion()}')
import h5py
print(f'h5py OK     — HDF5 version: {h5py.version.hdf5_version}')
import underworld3 as uw
print(f'underworld3 OK — version: {uw.__version__}')
"
    echo ""
    echo "==> Single-process MPI import check:"
    python3 -c "from mpi4py import MPI; print(f'mpi4py MPI import OK (rank 0 of 1)')"
    echo "==> All checks passed"
    echo ""
    echo "    NOTE: Multi-rank MPI tests must be run from a compute node (PBS job)."
    echo "    Example: mpirun -n 4 python3 -c \"from mpi4py import MPI; print(MPI.COMM_WORLD.rank)\""
}

# ============================================================
# ENTRY POINT
# ============================================================

load_env

if [ "${1}" = "install" ]; then
    echo ""
    echo "Starting shared installation..."
    echo "  BASE_PATH:  ${BASE_PATH}"
    echo "  UW3_PATH:   ${UW3_PATH}"
    echo "  UW3_BRANCH: ${UW3_BRANCH}"
    echo ""
    setup_pixi
    clone_uw3
    install_pixi_env
    install_mpi4py
    if ! check_petsc_exists; then
        install_petsc
    else
        echo "==> PETSc already installed, skipping"
    fi
    install_h5py
    if ! check_uw3_exists; then
        install_uw3
    else
        echo "==> Underworld3 already installed, skipping"
    fi
    verify_install
    fix_permissions
    echo ""
    echo "=========================================="
    echo "Shared installation complete!"
    echo "To activate: source $(realpath "${BASH_SOURCE[0]}")"
    echo "=========================================="
fi
