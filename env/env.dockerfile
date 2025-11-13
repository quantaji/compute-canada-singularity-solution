FROM docker.io/library/ubuntu:24.04
WORKDIR /
ENV TZ=America/Vancouver
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ >/etc/timezone
COPY ./env /env
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git curl wget make binutils nano unzip \
        libosmesa6 libgl1 \
        python3 python3-pip python3-dev build-essential && \
        rm -rf /var/lib/apt/lists/* 
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    chmod +x /Miniconda3-latest-Linux-x86_64.sh && \
    /Miniconda3-latest-Linux-x86_64.sh -b -p /miniconda3 && \
    rm -rf /Miniconda3-latest-Linux-x86_64.sh && \
    /miniconda3/bin/conda init bash && \
    chmod -R 777 /miniconda3
RUN export PATH="/miniconda3/bin:$PATH" && conda config --set auto_activate_base false
WORKDIR /
ENV ENV_FOLDER=/env
SHELL ["/bin/bash", "-c"] 
RUN export PATH="/miniconda3/bin:$PATH" && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r && \
    bash ${ENV_FOLDER}/install_env.sh && \
    rm -rf /root/.cache/*
ENV SHELL=/bin/bash \
    PATH=/miniconda3/envs/your_env/bin:/miniconda3/bin:$PATH \
    CONDA_PREFIX=/miniconda3/envs/your_env 
