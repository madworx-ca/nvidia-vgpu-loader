#!/usr/bin/env bash

################################################
# nvidia-vgpu-loader.sh
#
# Copyright (c) 2023 - SqueezeStudio -  Guy Madore
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# --
#
# This script is a utility for managing NVIDIA graphics hardware on 
# Ubuntu systems using the KVM hypervisor. It streamlines the setup 
# and allocation of virtual GPUs (vGPUs) by employing SR-IOV technology. 
# The script automatically initializes and generates unique identifiers 
# for each vGPU based on a user-defined profile. The main objective of 
# this script is to maintain a consistent configuration across system 
# reboots, thereby ensuring the persistent setup of vGPU instances. 
# As a result, the NVIDIA graphics device is used more efficiently and 
# manual configuration effort is significantly reduced. 
# This script is designed for systems with dedicated NVIDIA graphics cards.
################################################


## set desired profile here
declare -a nv_profile="nvidia-562"


#################################################
# Check if the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

# Function to check if SR-IOV is enabled on a device
function is_sriov_enabled() {
    local dev_id="0000:$1"
    local sriov_numvfs=$(cat /sys/bus/pci/devices/$dev_id/sriov_numvfs 2>/dev/null)

    if [[ $sriov_numvfs -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to initialize vGPU on Nvidia devices
function init_vgpu() {
    local dev_id="0000:$1"
    local uuid_file="./.uuid-file-${1}"

    # Check if SR-IOV is enabled
    if is_sriov_enabled $1; then
        echo "SR-IOV is already enabled on a device - device: $dev_id."
        echo "SR-IOV must be disabled on all devices before running."
        echo "Please disable it before running this script."
        exit 1
    fi

    # Enabling sr-iov on the nvidia card
    /usr/lib/nvidia/sriov-manage -e $dev_id

    # Get max_instances value from profile description
    local max_instances=$(awk -F "[,=]" '/max_instance/ {for(i=1;i<=NF;i++) if (gensub(/^[ \t]+|[ \t]+$/,"","g",$i)=="max_instance") print gensub(/^[ \t]+|[ \t]+$/,"","g",$(i+1))}' /sys/bus/pci/devices/$dev_id/virtfn0/mdev_supported_types/$nv_profile/description)

    # Check if the UUID file exists
    if [[ ! -f $uuid_file ]]; then
        # If the UUID file does not exist, generate new UUIDs and write them to the file
        echo "Profile=$nv_profile max_instance=$max_instances" 
        echo "UUID file for device $1 does not exist. Generating $max_instances new UUIDs..."
        for (( i=1; i<=$max_instances; i++ )); do
            local uuid=$(uuidgen)
            echo $uuid >> $uuid_file
        done
        echo "$max_instances new UUIDs generated and saved to $uuid_file"
    else
        echo "Profile=$nv_profile - max_instance=$max_instances"
        echo "UUID file $uuid_file for device $1 already exists."
        echo "Reassign UUID to Virtual Functions"
    fi

    # Read UUIDs from the UUID file
    readarray -t uuids < $uuid_file

    # Create vGPU profiles
        local vf_list=( $(ls -1 /sys/bus/pci/devices/$dev_id/ | grep virtfn | sort -V) )
        for (( index=0; index<$max_instances; index++ )); do
                if (( index >= ${#vf_list[@]} )); then
                echo "Not enough VFs for all instances. Some UUIDs may not be used."
                break
                fi
        echo "${uuids[$index]} > /sys/bus/pci/devices/$dev_id/${vf_list[$index]}/mdev_supported_types/$nv_profile/create"
        echo "${uuids[$index]}" > "/sys/bus/pci/devices/$dev_id/${vf_list[$index]}/mdev_supported_types/$nv_profile/create"
        done
}


# Get all Nvidia devices ID and initialize vGPU
lspci | grep NVIDIA | awk '{print $1}' | while read -r nvidia_id; do
    init_vgpu $nvidia_id
done
