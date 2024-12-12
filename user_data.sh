#!/usr/bin/env bash

# user_data script log filepath on ec2 instance: /var/log/cloud-init-output.log

set -euox pipefail

# https://docs.aws.amazon.com/ebs/latest/userguide/ebs-using-volumes.html
mount_ebs_volume() {
    local device_name="/dev/nvme1n1"
    local mount_point="/mnt/data"
    local ollama_path="${mount_point}/ollama"
    local open_webui_path="${mount_point}/open-webui"

    echo "Creating $mount_point directory..."
    mkdir -p "$mount_point"

    # Check if the device is already formatted
    if ! blkid | grep -q "$device_name"; then
        echo "Formatting $device_name as ext4..."
        mkfs.ext4 "$device_name"
    else
        echo "$device_name is already formatted."
    fi

    # Check if the device is already mounted
    if ! mount | grep -q "$device_name"; then
        echo "Mounting $device_name to $mount_point..."
        mount "$device_name" "$mount_point"
        
        # Add the device to /etc/fstab to ensure it mounts on boot
        echo "$device_name $mount_point ext4 defaults,nofail 0 2" >> /etc/fstab
    else
        echo "$device_name is already mounted."
    fi

    echo "Creating $ollama_path directory..."
    mkdir -p "$ollama_path"

    echo "Creating $open_webui_path directory..."
    mkdir -p "$open_webui_path"
}

# https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
install_docker() {
    # Add Docker's official GPG key:
    apt-get update -y 
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y

    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/index.html#pre-installation-actions
# https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/index.html#ubuntu
install_nvidia_driver() {
    # install kernel headers and development packages for the currently running kernel
    apt-get install -y "linux-headers-$(uname -r)"

    # install the cuda-keyring package
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
    dpkg -i cuda-keyring_1.1-1_all.deb

    apt-get update -y

    # install open kernel modules
    apt-get install -y nvidia-open
}

# https://github.com/ollama/ollama/blob/main/docs/docker.md
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installing-the-nvidia-container-toolkit
install_nvidia_container_toolkit() {
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update -y
    apt-get install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
}

mount_ebs_volume
install_docker
install_nvidia_driver
install_nvidia_container_toolkit
