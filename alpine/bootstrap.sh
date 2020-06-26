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

/etc/init.d/containerd start
