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
File `./env/env.dockerfile` is the dockerfile that builds the whole image. First it select a base image to build with
```dockerfile
FROM docker.io/library/ubuntu:24.04
```
The image will affect the system lib and packages version, the glibc version. If you are trying to reproduce someone else's work, it is better to use the same system if they also make it public. Another advantage of using container is that you can disentangle cluster's glibc version with the container's one, because some new software does not accept old system.
