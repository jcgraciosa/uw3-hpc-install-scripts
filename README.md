## Underworld3 installation scripts for different HPC systems
- Kaiju
- Gadi

### I. Kaiju
Script for installing and running Underworld3 sofware stack.
Uses Python 3.11 and Open MPI 4.1.2 (to update) modules. 

#### Installation:
Review script details: modules, paths, repository urls / branches etc.
$ source <this_script_name>
$ install_full_stack

N.B.: Can also run steps individually as follows:
1. install_python_dependencies
2. install_petsc
3. install_h5py
4. install_underworld3

#### To run: 
Source this file to open the environment

#### Other notes: 
- Will update the available Open MPI in Kaiju in the near future
- Job scheduler is available in Kaiju, but haven't tested it yet
