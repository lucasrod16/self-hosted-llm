#!/usr/bin/env bash

# user_data script log filepath on ec2 instance: /var/log/cloud-init-output.log

set -euox pipefail

# https://docs.aws.amazon.com/ebs/latest/userguide/ebs-using-volumes.html
# EBS volume is primarly used to persist open-webui chat data,
# models downloaded by ollama, and docker images.
mount_ebs_volume() {
    local volume_id="vol0f2153615108429a8"
    local timeout=15
    local interval=3
    local start_time
    start_time=$(date +%s)
    while ! lsblk --nvme | grep -q "$volume_id"; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))

        if [ "$elapsed" -ge "$timeout" ]; then
            echo "Error: Volume ($volume_id) is not attached. Ensure the EBS volume is attached."
            exit 1
        fi

        echo "Waiting for volume ($volume_id) to be attached... Retrying in $interval seconds."
        sleep $interval
    done


    local device_name
    device_name="/dev/$(lsblk --nvme | grep "vol0f2153615108429a8" | awk '{print $1}')"

    if file -s "$device_name" | grep "filesystem"; then
        echo "Device $device_name is already formatted."
    else
        echo "Formatting $device_name as ext4..."
        mkfs.ext4 "$device_name"
    fi

    local mount_point="/mnt/data"
    # https://docs.docker.com/engine/daemon/#daemon-data-directory
    local docker_data_directory="/var/lib/docker"

    if [ ! -d "$mount_point" ]; then
        echo "Creating mount point $mount_point..."
        mkdir -p "$mount_point"
    fi

     if [ ! -d "$docker_data_directory" ]; then
        echo "Creating docker mount point $docker_data_directory..."
        mkdir -p "$docker_data_directory"
    fi

    echo "Mounting $device_name to $mount_point..."
    mount "$device_name" "$mount_point"

    echo "Mounting $device_name to $docker_data_directory..."
    mount "$device_name" "$docker_data_directory"

    if mountpoint -q "$mount_point"; then
        echo "EBS volume successfully mounted at $mount_point."
    else
        echo "Error: Failed to mount $device_name at $mount_point."
        exit 1
    fi

    if mountpoint -q "$docker_data_directory"; then
        echo "EBS volume successfully mounted at $docker_data_directory."
    else
        echo "Error: Failed to mount $device_name at $docker_data_directory."
        exit 1
    fi

    echo "Creating directories within $mount_point..."
    mkdir -p "${mount_point}/ollama"
    mkdir -p "${mount_point}/open-webui"
}

mount_ebs_volume
systemctl restart docker
