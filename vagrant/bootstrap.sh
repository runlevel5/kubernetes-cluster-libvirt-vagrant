#!/bin/bash
set -e

apt-get update

# Install containerd
apt-get install -y containerd
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

export K8S_VERSION="1.18.2"
export DOWNLOAD_URL="https://github.com/runlevel5/kubernetes-packages/releases/download/v$K8S_VERSION"

# install kublet
cd /tmp
wget "$DOWNLOAD_URL/kubernetes-cni_0.7.5-0_ubuntu_18.04_$(arch).deb"
dpkg -i kubernetes-cni_0.7.5-0_ubuntu_18.04_$(arch).deb

apt-get install -y socat iproute2 ebtables ethtool conntrack
cd /tmp
wget "$DOWNLOAD_URL/kubelet_$K8S_VERSION-0_ubuntu_18.04_$(arch).deb"
dpkg -i kubelet_$K8S_VERSION-0_ubuntu_18.04_$(arch).deb

# configure kubelet to use containerd as CRI plugin
cat << EOF | tee /etc/default/kubelet
KUBELET_EXTRA_ARGS="--container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF

mkdir -p /etc/systemd/system/kubelet.service.d
cat << EOF | tee /etc/systemd/system/kubelet.service.d/00-kubelet.conf
[Service]
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet \$KUBELET_EXTRA_ARGS
EOF

systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet

# Prevent conflicts between docker iptables (packet filtering) rules and k8s pod communication
# See https://github.com/kubernetes/kubernetes/issues/40182 for further details.
iptables -P FORWARD ACCEPT

# install kubectl
cd /tmp
wget "$DOWNLOAD_URL/kubectl_$K8S_VERSION-0_ubuntu_18.04_$(arch).deb"
dpkg -i kubectl_$K8S_VERSION-0_ubuntu_18.04_$(arch).deb

# install crictl
cd /tmp
wget "$DOWNLOAD_URL/cri-tools_1.18.0-0_ubuntu_18.04_$(arch).deb"
dpkg -i cri-tools_1.18.0-0_ubuntu_18.04_$(arch).deb

cat << EOF | tee  /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: true
EOF

# install kubeadm
cd /tmp
wget "$DOWNLOAD_URL/kubeadm_$K8S_VERSION-0_ubuntu_18.04_$(arch).deb"
dpkg -i kubeadm_$K8S_VERSION-0_ubuntu_18.04_$(arch).deb

# clean up
rm /tmp/*.deb

# disable swap
sed -i '/swap/d' /etc/fstab
swapoff -a

# Update hosts file
echo "Update /etc/hosts file"
cat >>/etc/hosts<<EOF
172.42.42.100 kmaster.example.com kmaster
172.42.42.101 kworker1.example.com kworker1
172.42.42.102 kworker2.example.com kworker2
EOF

