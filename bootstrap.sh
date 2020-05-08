#!/bin/bash
set -e

# Install CRI-O
echo "[CRI] Installing CRI-O"
modprobe overlay
modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/Debian_10/ /'  >> /etc/apt/sources.list.d/libcontainers.list
wget -nv https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/Debian_10/Release.key -O- | sudo apt-key add -
apt-get update && apt-get install -y cri-o-1.17

systemctl daemon-reload
systemctl start crio


# Install kubelet
apt-get install -y socat ebtables ethtool conntrack
cd /tmp
wget https://github.com/runlevel5/kubernetes-packages/blob/master/debian-10/ppc64le/kubernetes-cni_0.7.5-0_ppc64el.deb
dpkg -i kubernetes-cni_0.7.5-0_ppc64el.deb
wget https://github.com/runlevel5/kubernetes-packages/blob/master/debian-10/ppc64le/kubelet_1.18.2-0_ppc64el.deb
dpkg -i kubelet_1.18.2-0_ppc64el.deb
cat << EOF | tee /etc/default/kubelet
KUBELET_EXTRA_ARGS="--container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/crio/crio.sock"
EOF
systemctl daemon-reload
systemctl start kubelet
rm /tmp/kubernetes-cni_0.7.5-0_ppc64el.deb
rm /tmp/kubelet_1.18.2-0_ppc64el.deb

# Install kubectl
cd /tmp
wget https://github.com/runlevel5/kubernetes-packages/blob/master/debian-10/ppc64le/kubectl_1.18.2-0_ppc64el.deb
dpkg -i kubectl_1.18.2-0_ppc64el.deb
rm /tmp/kubectl_1.18.2-0_ppc64el.deb

# Install critool
cd /tmp
wget https://github.com/runlevel5/kubernetes-packages/blob/master/debian-10/ppc64le/cri-tools_1.18.0-0_ppc64el.deb
dpkg -i cri-tools_1.18.0-0_ppc64el.deb
cat << EOF | tee  /etc/crictl.yaml
runtime-endpoint: unix:///run/crio/crio.sock
image-endpoint: unix:///run/crio/crio.sock
timeout: 10
debug: true
EOF
rm /tmp/cri-tools_1.18.0-0_ppc64el.deb

# Install kubeadm
cd /tmp
wget https://github.com/runlevel5/kubernetes-packages/blob/master/debian-10/ppc64le/kubeadm_1.18.2-0_ppc64el.deb
dpkg -i kubeadm_1.18.2-0_ppc64el.deb
rm /tmp/kubeadm_1.18.2-0_ppc64el.deb

# Update hosts file
echo "[TASK 1] Update /etc/hosts file"
cat >>/etc/hosts<<EOF
172.42.42.100 kmaster.example.com kmaster
172.42.42.101 kworker1.example.com kworker1
172.42.42.102 kworker2.example.com kworker2
EOF

# Disable swap
sed -i '/swap/d' /etc/fstab
swapoff -a
