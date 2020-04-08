#!/bin/bash
set -e

# Initialize Kubernetes
echo "[TASK 13] Initialize Kubernetes Cluster"
kubeadm init --cri-socket /run/containerd/containerd.sock --apiserver-advertise-address=172.42.42.100 --pod-network-cidr=192.168.0.0/16 >> /root/kubeinit.log 

# Copy Kube admin config
echo "[TASK 14] Copy kube admin config to user .kube directory"
mkdir /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# Deploy Calico network
echo "[TASK 15] Deploy Calico network"
su - ubuntu -c "kubectl create -f https://docs.projectcalico.org/manifests/calico.yaml"

# Generate Cluster join command
echo "[TASK 16] Generate and save cluster join command to /joincluster.sh"
kubeadm token create --print-join-command > /home/ubuntu/join_cluster.sh
chown ubuntu:ubuntu /home/ubuntu/join_cluster.sh