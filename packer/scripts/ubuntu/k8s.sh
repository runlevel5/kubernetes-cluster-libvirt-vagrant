#!/bin/bash

# Install containerd
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

if [ $(arch) == "ppc64le" ]; then
  add-apt-repository \
    "deb [arch=ppc64el] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
elif [ $(arch) == "x86_64" ]; then
  add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
else
  add-apt-repository \
    "deb [arch=$(arch)] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
fi

apt-get update
apt-get install -y containerd.io
cat > /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
systemctl start containerd

K8S_VERSION=`curl -sL https://dl.k8s.io/release/stable.txt`

# install kublet
cd /usr/bin
wget https://dl.k8s.io/release/$(K8S_VERSION)/bin/linux/$(arch)/kubelet
chmod +x ./kubelet

cat << EOF | tee /lib/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
EnvironmentFile=-/etc/default/kubelet
ExecStart=/usr/bin/kubelet $KUBELET_EXTRA_ARGS
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# configure kubelet to use containerd as CRI plugin
mkdir -p  /etc/default
cat << EOF | tee /etc/default/kubelet
KUBELET_EXTRA_ARGS="--container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF

systemctl daemon-reload
systemctl restart containerd

# Prevent conflicts between docker iptables (packet filtering) rules and k8s pod communication
# See https://github.com/kubernetes/kubernetes/issues/40182 for further details.
iptables -P FORWARD ACCEPT

systemctl enable kubelet
systemctl start kubelet

# install kubectl
cd /usr/bin
wget https://dl.k8s.io/release/$(K8S_VERSION)/bin/linux/$(arch)/kubectl
chmod +x ./kubectl

# install kubeadm
cd /usr/bin
wget https://dl.k8s.io/release/$(K8S_VERSION)/bin/linux/$(arch)/kubeadm
chmod +x ./kubeadm

# disable swap
sed -i '/swap/d' /etc/fstab
swapoff -a

# install crictl
VERSION="v1.18.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-$(arch).tar.gz
tar zxvf crictl-$VERSION-linux-$(arch).tar.gz -C /usr/bin
rm -f crictl-$VERSION-linux-$(arch).tar.gz

cat << EOF | tee  /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: true
EOF
