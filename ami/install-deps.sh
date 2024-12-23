#!/usr/bin/env bash

set -euox pipefail

export DEBIAN_FRONTEND=noninteractive

# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
install_docker() {
    # Add Docker's official GPG key:
    sudo apt-get update -y 
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y

    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/index.html#pre-installation-actions
# https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/index.html#ubuntu
install_nvidia_driver() {
    # install kernel headers and development packages for the currently running kernel
    sudo apt-get install -y "linux-headers-$(uname -r)"

    # install the cuda-keyring package
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt-get update -y
    rm cuda-keyring_1.1-1_all.deb

    # install open kernel modules
    sudo apt-get install -y nvidia-open
}

# https://github.com/ollama/ollama/blob/main/docs/docker.md
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installing-the-nvidia-container-toolkit
install_nvidia_container_toolkit() {
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    sudo apt-get update -y
    sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
}

install_docker
install_nvidia_driver
install_nvidia_container_toolkit
