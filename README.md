# compute-canada-singularity-solution
This is a guide for how to use Singularity container in SLURM system like those for some of the Compute Canada clusters. 
1. The first purpose for this is that, these clusters use network storage and is very inefficient for loading small size but huge amount of data. Singularity is a container tool that pack all softwares in the environment into one single `.sif` file.
2. The second purpose is to more freely use any versions of software. Usually these clusters maintain its own software stack starting from a gcc compiler, and everything is compiled from it. The available versions or combinations of available version can not be fullfilled if you want to replicate some others' work that have a specific set of environment. Therefore, it is better to use Anaconda and pypi where the versions are the most complete.

## Overall guideline
The stratagy is to
- compute-canada-singularity-solution
  - Overall guideline
  - Build the docker file
    - Install system packages
    - install Miniconda
    - Build conda environment
  - Building the docker image and export it to singularity/apptainer format
  - Running SLURM scripts with apptainer

## Build the docker file
File [`./env/env.dockerfile`](./env/env.dockerfile) is the dockerfile that builds the whole image. First it select a base image to build with
```dockerfile
FROM docker.io/library/ubuntu:24.04
```
The image will affect the system lib and packages version, the glibc version. If you are trying to reproduce someone else's work, it is better to use the same system if they also make it public. Another advantage of using container is that you can disentangle cluster's glibc version with the container's one, because some new software does not accept old system.

### Install system packages
Then we will install some necessary software that is envorinment agnostic or very universal or very useful for debugging:
```dockerfile
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git curl wget make binutils nano unzip \
        libosmesa6 libgl1 \
        rm -rf /var/lib/apt/lists/* 
```
Here I install git curl wget nano unzip, which is very essential for downloading things, quick edit, and other stuff. Then I also install osmesa because I am using a headless machine for rendering, you can skip this if you don't need to. If you are replicating someother's work, they may also metion the packages they install and it is the time to install. Be careful that different linux distribution or different versions of it may use different name for the same packages. 

You may need to constantly tune the installed packages here.

### install Miniconda 
The next step is to install Anaconda or miniconda, the headless and miminal version of Anaconda. Usually conda is known for building python environment, but it is capable of building environment for all kinds of application.
```dockerfile
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    chmod +x /Miniconda3-latest-Linux-x86_64.sh && \
    /Miniconda3-latest-Linux-x86_64.sh -b -p /miniconda3 && \
    rm -rf /Miniconda3-latest-Linux-x86_64.sh && \
    /miniconda3/bin/conda init bash && \
    chmod -R 777 /miniconda3
```
In the above script, I install the miniconda into the `/miniconda3` folder inside the container (virtual machine). Then I use `conda init` to setup conda command in the bash shell. Then I remove the installation packages to reduce the size of the container.


The next step is to build a conda environement, which is illustrated in the following docker command:
```dockerfile
RUN export PATH="/miniconda3/bin:$PATH" && conda config --set auto_activate_base false
WORKDIR /
ENV ENV_FOLDER=/env
SHELL ["/bin/bash", "-c"] 
RUN export PATH="/miniconda3/bin:$PATH" && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
    bash ${ENV_FOLDER}/install_env.sh && \
    rm -rf /root/.cache/*
```
What it does is it sets up environment variable for conda (usually this is not enough, conda sometimes cannot automatically be activated in a non-interactive shell, but we have solution). It also ask conda to accept some agreements. All the conda environment installation is in the [`install_env.sh`](./env/install_env.sh) file.

### Build conda environment
Different people has different style of building environment. Someone use `venv` or `virtualenv` or `uv` or all software from `conda`. From my experience, `conda-forge` is very slow for resolving dependency issue, but conda provides far more packages than pure python environment manager. Therefore my principle is 
- **Use conda to install necessary non-python packages and python itself. Then use PIP to install all python packages.**

First setup your environment name
```bash
env_name=your_env_name
```

Then you need to specify your version to install:
```bash
export INSTALLED_PYTHON_VERSION="3.11"
export INSTALLED_CUDA_VERSION="12.4"
export INSTALLED_CUDA_ABBREV="cu124"
export INSTALLED_GCC_VERSION="11.2.0"
export INSTALLED_PYTORCH_VERSION="2.5.1"
export INSTALLED_TORCHVISION_VERSION="0.20.1"
export INSTALLED_TORCHAUDIO_VERSION="2.5.1"
```
If you are replication some other's work, just look into there repository and see if they make it public. It is always better to use the **most similar environment**. Note that, if you are using a local machine or using gpu on SLURM system, the nvidia's driver's cuda version is **OKAY to be higher or equal** to the cuda version specified here, but **NOT lower**. (PS: you can check with `nvidia-smi` command on your own machine, or `module load cuda/12.9` on a cluster.)

Here are some suggestions for combinations of version:
- `gcc` version is very tolerable, just use the minimum gcc version for the target cuda version.
- Some newer version of pip packages only have prebuild wheel for higher version of python, therefore, you might need to check the python packages have pre-build wheel for the target python version (`py38`, `py310`, etc).
- pytorch's version is tightly related with cuda version, for a certain torch version, it only have a few supported pre-build cuda-accelerated version. If you cannot reconcile this, you might need to build pytorch from scratch. You can check this out on their [historical release page](https://pytorch.org/get-started/previous-versions/).
- `torchvision` and `torchaudio` version are strictly tight to `torch` version.
- some non-pip packages like `mmcv` might have host their own pre-build website. (Building them on your own is very painful! but I will show how to do it), usuall these software are tighted to specific version of cuda, torch, and python. An example would be [here](https://mmcv.readthedocs.io/en/latest/get_started/installation.html#install-with-pip). If you are planning to install some of these kind of packages, you should really checkout their supported version before you decide which versions to install.


Then the scripts will install first some of the conda packages, like `nvcc` and `gcc`. This is prepared for cases you cannot avoid compiling things when install some packages like `pytorch3d` or `MinkowskiEngine`, you need the correct version of cuda and C++ compiler.
```bash
conda create --name $env_name --yes python=${INSTALLED_PYTHON_VERSION}
eval "$(conda shell.bash hook)"
conda activate $env_name

conda install -y -c conda-forge gxx=${INSTALLED_GCC_VERSION} libstdcxx-ng=15.2.0
conda install -y -c "nvidia/label/cuda-${INSTALLED_CUDA_VERSION}" cuda

conda deactivate
conda activate ${env_name}
```
The `eval "$(conda shell.bash hook)"` command is useful if it is a scripts not an interactive environment. You can also install some other software such as ffmpeg (this you can also install from ubuntu), as long as conda provides the software.

Then the scripts will setup the environment variables so that any future compiling task will be noticed with correct path
```bash
conda_home="$(conda info | grep "active env location : " | cut -d ":" -f2-)"
conda_home="${conda_home#"${conda_home%%[![:space:]]*}"}"

export AM_I_DOCKER=1
export BUILD_WITH_CUDA=1
export CUDA_HOST_COMPILER="$conda_home/bin/gcc"
export CUDA_PATH="$conda_home"
export CUDA_HOME=$CUDA_PATH
export FORCE_CUDA=1
export MAX_JOBS=6 # number of threads for compiling
export TORCH_CUDA_ARCH_LIST="7.5 8.0 8.6 8.7 8.9 9.0" 
export PYTHONPATH=${REPO_MNT}:${PYTHONPATH:-}
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:$LD_LIBRARY_PATH"
```

The tricky part is the `export TORCH_CUDA_ARCH_LIST="7.5 8.0 8.6 8.7 8.9 9.0" ` command. If you are planning to use `H100` or other new version of card, be sure to include the architecture number, which you can find [here](https://developer.nvidia.com/cuda-gpus). (Another tricky thing is that some new cards does not very support for old cuda... If you are using very new machine, it might be possible that you cannot run old code directly...)


Then the scripts try to install torch-related packages and other packages, and packages you might need to compile. Note that this `install_env.sh` is just an **EXAMPLE**.
```bash

# Pytorch
pip install torch==${INSTALLED_PYTORCH_VERSION} torchvision==${INSTALLED_TORCHVISION_VERSION} torchaudio==${INSTALLED_TORCHAUDIO_VERSION} --index-url https://download.pytorch.org/whl/${INSTALLED_CUDA_ABBREV}
pip install torch-cluster -f https://data.pyg.org/whl/torch-${INSTALLED_PYTORCH_VERSION}+${INSTALLED_CUDA_ABBREV}.html

# other packages
pip install -r "${ENV_FOLDER}/requirements.txt"
```


In the scripts, I try to install pytorch3d by compiling it from source, this is where all the environment variables become useful:
```bash
pip install "git+https://github.com/facebookresearch/pytorch3d.git@stable"
```
Compiling sometimes is inevitable. For example here, the official support for pytorch3d is only up to torch 2.4, but we are building it for torch 2.5. If you really need some functions from some packages, this adaptation is necessart.


## Building the docker image and export it to singularity/apptainer format

Build docker image
```bash
docker build --tag your_env_tag -f env/env.dockerfile .
```
Run the docker image
```bash
# Run
docker run --gpus all -i --rm -t your_env_tag /bin/bash
```
convert docker into apptainer
```bash
apptainer build your_name.sif docker-daemon://your_env_tag:latest
```


## Running SLURM scripts with apptainer
With all the complication above, using singlularity/apptainer is very simple. The only two module you have to add is the singularity/apptainer and the cuda driver:
```bash
module --force purge
module load StdEnv apptainer cuda/12.9
```

Here is a full sbatch example:
```bash
#!/bin/bash
#SBATCH --job-name=baseline_training
#SBATCH --output=outlog_%j.out
#SBATCH --error=errlog_%j.out
#SBATCH --gpus-per-node=h100:4
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=256G
#SBATCH --time=96:00:00



REPO_HOST="/home/username/Repo"
SIF_IMG="/home/username/Repo/your_env_tag.sif"
DATASET_REPO="/scratch/username"


module --force purge
module load StdEnv apptainer cuda/12.9

apptainer exec --nv \
  --bind ${DATASET_REPO}:/dataset \
  ${SIF_IMG} \
  bash <<'BASH'
set -eo pipefail

CONDA_ENV_NAME="your_env"

export PATH=/miniconda3/bin:$PATH
eval "$(conda shell.bash hook)"
conda activate ${CONDA_ENV_NAME}
conda deactivate

conda activate ${CONDA_ENV_NAME}
conda_home="$(conda info | grep "active env location : " | cut -d ":" -f2-)"
conda_home="${conda_home#"${conda_home%%[![:space:]]*}"}"

export PYTHONPATH=${REPO_MNT}:${PYTHONPATH:-}
export CUDA_HOST_COMPILER="$conda_home/bin/gcc"
export CUDA_PATH="$conda_home"
export CUDA_HOME=$CUDA_PATH
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:$LD_LIBRARY_PATH"
export PYOPENGL_PLATFORM=osmesa
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

command -v nvcc
command -v pip
command -v python


bash scripts/train.sh --config configs/default.yaml
BASH

```
