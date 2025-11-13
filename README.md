# compute-canada-singularity-solution
This is a guide for how to use Singularity container in SLURM system like those for some of the Compute Canada clusters. 
1. The first purpose for this is that, these clusters use network storage and is very inefficient for loading small size but huge amount of data. Singularity is a container tool that pack all softwares in the environment into one single `.sif` file.
2. The second purpose is to more freely use any versions of software. Usually these clusters maintain its own software stack starting from a gcc compiler, and everything is compiled from it. The available versions or combinations of available version can not be fullfilled if you want to replicate some others' work that have a specific set of environment. Therefore, it is better to use Anaconda and pypi where the versions are the most complete.

## Overall guideline
The stratagy is to
1. First build a docker image that installs all the library, packages, and build the environment
2. convert it into a singularity image
3. upload it onto the cluster (usually these clusters do not have internet access during jobs, so it is a better idea to build the environment locally) and run the container version training scripts.

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
