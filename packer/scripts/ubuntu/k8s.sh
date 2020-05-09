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
cd /tmp
wget -sL https://github.com/runlevel5/kubernetes-packages/releases/download/$(K8S_VERSION)/kubernetes-cni_0.7.5-0_ubuntu_18.04_$(arch).deb
dpkg -i kubernetes-cni_0.7.5-0_ubuntu_18.04_$(arch).deb

apt-get install -y socat iproute2 ebtables ethtool conntrack
cd /tmp
wget -sL https://github.com/runlevel5/kubernetes-packages/releases/download/$(K8S_VERSION)/kubelet_1.18.2-0_ubuntu_18.04_$(arch).deb
dpkg -i kubelet_1.18.2-0_ubuntu_18.04_$(arch).deb

# configure kubelet to use containerd as CRI plugin
mkdir -p  /etc/default
cat << EOF | tee /etc/default/kubelet
KUBELET_EXTRA_ARGS="--container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF

# Prevent conflicts between docker iptables (packet filtering) rules and k8s pod communication
# See https://github.com/kubernetes/kubernetes/issues/40182 for further details.
iptables -P FORWARD ACCEPT

# install kubectl
cd /tmp
wget -sL https://github.com/runlevel5/kubernetes-packages/releases/download/$(K8S_VERSION)/kubectl_1.18.2-0_ubuntu_18.04_$(arch).deb
dpkg -i kubectl_1.18.2-0_ubuntu_18.04_$(arch).deb

# install kubeadm
cd /tmp
wget -sL https://github.com/runlevel5/kubernetes-packages/releases/download/$(K8S_VERSION)/kubeadm_1.18.2-0_ubuntu_18.04_$(arch).deb
dpkg -i kubeadm_1.18.2-0_ubuntu_18.04_$(arch).deb

# install crictl
cd /tmp
wget -sL https://github.com/runlevel5/kubernetes-packages/releases/download/$(K8S_VERSION)/cri-tools_1.18.0-0_ubuntu_18.04_$(arch).deb
dpkg -i cri-tools_1.18.0-0_ubuntu_18.04_$(arch).deb

cat << EOF | tee  /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: true
EOF


# clean up
rm /tmp/*.deb

systemctl enable kubelet
systemctl start kubelet

# disable swap
sed -i '/swap/d' /etc/fstab
swapoff -a
