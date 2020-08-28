#!/bin/bash
set -e

# Initialize Kubernetes
echo "Initialize Kubernetes Cluster"
kubeadm config images pull

# Let's wait for kubeadm init timeout
kubeadm init --cri-socket /run/containerd/containerd.sock \
             --apiserver-advertise-address=172.42.42.100 \
             --pod-network-cidr=192.168.0.0/16 \
             --v=5 || true

rc-service kubelet start

# start kubeadm process again
kubeadm init --cri-socket /run/containerd/containerd.sock \
             --apiserver-advertise-address=172.42.42.100 \
             --pod-network-cidr=192.168.0.0/16 \
             --v=5 \
             --ignore-preflight-errors=Port-6443,Port-10259,Port-10257,Port-10250,Port-2379,Port-2380,DirAvailable--var-lib-etcd,FileAvailable--etc-kubernetes-manifests-kube-apiserver.yaml,FileAvailable--etc-kubernetes-manifests-kube-controller-manager.yaml,FileAvailable--etc-kubernetes-manifests-kube-scheduler.yaml,FileAvailable--etc-kubernetes-manifests-etcd.yaml


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

echo "Deploy Flannel CNI"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Generate Cluster join command
echo "Generate and save cluster join command to /join_cluster.sh"
kubeadm token create --print-join-command > /home/vagrant/join_cluster.sh
chown vagrant:vagrant /home/vagrant/join_cluster.sh
