# nvidia-vgpu-loader

Description:
This script is a utility for managing NVIDIA graphics hardware on 
Ubuntu systems using the KVM hypervisor. It streamlines the setup 
and allocation of virtual GPUs (vGPUs) by employing SR-IOV technology. 

The script automatically initializes and generates unique identifiers 
for each vGPU based on a user-defined profile. The main objective of 
this script is to maintain a consistent configuration across system 
reboots, thereby ensuring the persistent setup of vGPU instances. 
As a result, the NVIDIA graphics device is used more efficiently and 
manual configuration effort is significantly reduced. 

This script is designed for systems with dedicated NVIDIA graphics cards.


Note:

The script must be installed in the folder: /opt/nvidia-vgpu-loader/
if you change the path location don't forget to update the nvidia-vgpu-loader.service file.
