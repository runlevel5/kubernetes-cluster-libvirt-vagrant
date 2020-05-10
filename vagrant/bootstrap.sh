#!/bin/bash
set -e

echo "nameserver 8.8.8.8" > /etc/resolv.conf

download() {
  while [ 1 ]; do
    wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 --continue $1
    if [ $? = 0 ]; then break; fi; # check return value, break if successful (0)
    sleep 1s;
  done;
}

# Install containerd
# Fetch the latest version from sid repo
echo "deb http://ftp.au.debian.org/debian sid main" >> /etc/apt/sources.list.d/sid.list
apt-get update
cd /tmp && apt-get download libseccomp2 runc containerd && dpkg -i *.deb
rm /etc/apt/sources.list.d/sid.list
apt-get update

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
download "$DOWNLOAD_URL/kubernetes-cni_0.7.5-0_debian_10_$(arch).deb"
dpkg -i kubernetes-cni_0.7.5-0_debian_10_$(arch).deb

apt-get install -y socat iproute2 ebtables ethtool conntrack
export PATH="/sbin:$PATH"

cd /tmp
download "$DOWNLOAD_URL/kubelet_$K8S_VERSION-0_debian_10_$(arch).deb"
dpkg -i kubelet_$K8S_VERSION-0_debian_10_$(arch).deb

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

# Prevent conflicts between docker iptables (packet filtering) rules and k8s pod communication
# See https://github.com/kubernetes/kubernetes/issues/40182 for further details.
iptables -P FORWARD ACCEPT

# install kubectl
cd /tmp
download "$DOWNLOAD_URL/kubectl_$K8S_VERSION-0_debian_10_$(arch).deb"
dpkg -i kubectl_$K8S_VERSION-0_debian_10_$(arch).deb

# install crictl
cd /tmp
download "$DOWNLOAD_URL/cri-tools_1.18.0-0_debian_10_$(arch).deb"
dpkg -i cri-tools_1.18.0-0_debian_10_$(arch).deb

cat << EOF | tee  /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: true
EOF

systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet

# install kubeadm
cd /tmp
download "$DOWNLOAD_URL/kubeadm_$K8S_VERSION-0_debian_10_$(arch).deb"

#dpkg -i kubeadm_$K8S_VERSION-0_debian_10_$(arch).deb

# clean up
#rm /tmp/*.deb

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

