#!/bin/bash
set -e

# Alpine Edge only! Let's hope alpine 3.13 or 3.14 would have k8s in main tree
echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories
echo http://dl-cdn.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories

apk add containerd containerd-openrc

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

sysctl -p
sysctl -p /etc/sysctl.d/99-kubernetes-cri.conf

mkdir -p /etc/containerd
# See https://git.alpinelinux.org/aports/commit/?id=72a355e1c8437c4e32a3e22bc3888905a6e545ba for details on why we need update the plugin dir
containerd config default | sed "s|/opt/cni/bin|/usr/libexec/cni|g" > /etc/containerd/config.toml

rc-update add containerd default
rc-service containerd start

apk add kubernetes conntrack-tools kubeadm kubectl kubelet cri-tools
rc-update add kubelet default

# Prevent conflicts between docker iptables (packet filtering) rules and k8s pod communication
# See https://github.com/kubernetes/kubernetes/issues/40182 for further details.
iptables -P FORWARD ACCEPT

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
