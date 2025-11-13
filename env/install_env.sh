# exit when any command fails
set -e

# # make sure submodules are updated
# git submodule update --init --recursive

env_name=your_env_name
echo "${ENV_FOLDER}"

# decide software version
export INSTALLED_PYTHON_VERSION="3.11"
export INSTALLED_CUDA_VERSION="12.4"
export INSTALLED_CUDA_ABBREV="cu124"
export INSTALLED_GCC_VERSION="11.2.0"
export INSTALLED_PYTORCH_VERSION="2.5.1"
export INSTALLED_TORCHVISION_VERSION="0.20.1"
export INSTALLED_TORCHAUDIO_VERSION="2.5.1"

echo ${INSTALLED_PYTHON_VERSION}
echo ${INSTALLED_CUDA_VERSION}
echo ${INSTALLED_CUDA_ABBREV}
echo ${INSTALLED_GCC_VERSION}
echo ${INSTALLED_PYTORCH_VERSION}
echo ${INSTALLED_TORCHVISION_VERSION}
echo ${INSTALLED_TORCHAUDIO_VERSION}

# create env, install gcc cuda and openblas
conda create --name $env_name --yes python=${INSTALLED_PYTHON_VERSION}
eval "$(conda shell.bash hook)"
conda activate $env_name

conda install -y -c conda-forge gxx=${INSTALLED_GCC_VERSION} libstdcxx-ng=15.2.0
conda install -y -c "nvidia/label/cuda-${INSTALLED_CUDA_VERSION}" cuda

conda deactivate
conda activate ${env_name}

conda_home="$(conda info | grep "active env location : " | cut -d ":" -f2-)"
conda_home="${conda_home#"${conda_home%%[![:space:]]*}"}"

export AM_I_DOCKER=1
export BUILD_WITH_CUDA=1
export CUDA_HOST_COMPILER="$conda_home/bin/gcc"
export CUDA_PATH="$conda_home"
export CUDA_HOME=$CUDA_PATH
export FORCE_CUDA=1
export MAX_JOBS=6
export TORCH_CUDA_ARCH_LIST="7.5 8.0 8.6 8.7 8.9 9.0"
export PYTHONPATH=${REPO_MNT}:${PYTHONPATH:-}
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:$LD_LIBRARY_PATH"

echo ${conda_home}

which python
which pip
which nvcc

# Pytorch
pip install torch==${INSTALLED_PYTORCH_VERSION} torchvision==${INSTALLED_TORCHVISION_VERSION} torchaudio==${INSTALLED_TORCHAUDIO_VERSION} --index-url https://download.pytorch.org/whl/${INSTALLED_CUDA_ABBREV}
pip install torch-cluster -f https://data.pyg.org/whl/torch-${INSTALLED_PYTORCH_VERSION}+${INSTALLED_CUDA_ABBREV}.html

# other packages
pip install -r "${ENV_FOLDER}/requirements.txt"

# pyrender
pip install --no-deps -U PyOpenGL PyOpenGL_accelerate

# pytorch3d
pip install "git+https://github.com/facebookresearch/pytorch3d.git@stable"
