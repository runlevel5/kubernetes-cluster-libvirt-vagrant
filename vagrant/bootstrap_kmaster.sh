#!/bin/bash
set -e

# Initialize Kubernetes
echo "Initialize Kubernetes Cluster"
kubeadm config images pull
kubeadm init --cri-socket /run/containerd/containerd.sock --apiserver-advertise-address=172.42.42.100 --pod-network-cidr=192.168.0.0/16 --v=5

# Copy Kube admin config
echo "Copy kube admin config to user .kube directory"

# for root user
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config 
chown $(id -u):$(id -g) $HOME/.kube/config

# for vagrant user
mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

echo "Deploy Calico CNI"
kubectl create -f https://docs.projectcalico.org/manifests/calico.yaml

# Generate Cluster join command
echo "Generate and save cluster join command to /join_cluster.sh"
kubeadm token create --print-join-command > /home/vagrant/join_cluster.sh
chown vagrant:vagrant /home/vagrant/join_cluster.sh
