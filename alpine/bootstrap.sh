#!/bin/bash
set -e

apk add containerd

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
containerd config default > /etc/containerd/config.toml

# NOTE: Copy from https://gitweb.gentoo.org/repo/gentoo.git/tree/app-emulation/containerd/files/containerd.initd
cat > /etc/init.d/containerd <<EOF
#!/sbin/openrc-run

description="Containerd container runtime"
command="/usr/bin/containerd"
pidfile="${pidfile:-/run/${RC_SVCNAME}.pid}"
start_stop_daemon_args="--background --make-pidfile --stderr /var/log/${RC_SVCNAME}/${RC_SVCNAME}.log --stdout /var/log/${RC_SVCNAME}/${RC_SVCNAME}.log"

start_pre() {
	checkpath -m 0750 -d /var/log/${RC_SVCNAME}

	ulimit -n 1048576

	# Having non-zero limits causes performance problems due to accounting overhead
	# in the kernel. We recommend using cgroups to do container-local accounting.
	ulimit -u unlimited

	return 0
}

start_post() {
	ewaitfile 5 /run/containerd/containerd.sock
}
EOF

chmod +x /etc/init.d/containerd
rc-update add containerd default
rc-service containerd start


# Install crictl
cd /tmp
VERSION="v1.17.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-ppc64le.tar.gz
tar xzvf crictl-$VERSION-linux-ppc64le.tar.gz
mv ./crictl /usr/bin

cat << EOF | tee  /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: true
EOF

# Install conntrack
apk add conntrack-tools

# Configure kubelet

cat > /var/lib/kubelet/config.yaml <<EOF
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
clusterDNS:
- 10.96.0.10
clusterDomain: cluster.local
cpuManagerReconcilePeriod: 0s
evictionPressureTransitionPeriod: 0s
fileCheckFrequency: 0s
healthzBindAddress: 127.0.0.1
healthzPort: 10248
httpCheckFrequency: 0s
imageMinimumGCAge: 0s
kind: KubeletConfiguration
nodeStatusReportFrequency: 0s
nodeStatusUpdateFrequency: 0s
rotateCertificates: true
runtimeRequestTimeout: 15m
staticPodPath: /etc/kubernetes/manifests
streamingConnectionIdleTimeout: 0s
syncFrequency: 0s
volumeStatsAggPeriod: 0s
EOF

cat > /var/lib/kubelet/kubeadm-flags.env <<EOF
export KUBELET_EXTRA_ARGS="--container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock --config=/var/lib/kubelet/config.yaml"
EOF
rc-update add kubelet default
/etc/init.d/kubelet start

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
