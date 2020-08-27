## Kubernetes Cluster with libvirt/kvm

Have you just picked up k8s? Well firstly you should look into `minikube` if you
are after a simple one-node cluster for learning.

If you fail to get minikube to work on your machine, you could set up a local
cluster with libvirt. DO NOT USE it for production.

This cluster consists of 1 master and 2 worker nodes that are configured with:

* CRI: containerd
* CNI: calico
* SMI: none

### Prerequisites

* Linux (amd64|ppc64le|arm64)
* qemu
* vagrant
* vagrant-libvirt

### Get started

1. Orchestrate cluster:

```
cd ubuntu && vagrant up
```

4. Verify that you could ssh into either master or worker:

```
vagrant ssh kmaster
vagrant ssh kworker1
vagrant ssh kworker2
```

5. Check the health of the cluster:

```
vagrant ssh kmaster
kubectl cluster-info
kubectl get cs # should show everything healthy
```

6. Setting up connection to cluster from your host:

```
vagrant ssh-config >> ~/.ssh/config
scp kmaster:/home/ubuntu/.kube/config ~/.kube/
config
kubectl cluster-info
```

### Issues

If Vagrant gets stuck at "waiting to get IP address" part, it is likely that libvirt VM fail to assign IP address.
The workaround is to Ctrl-C to cancel the operation, then `vagrant destroy && vagrant up` again. 

### Credits

Codes are based on:

* https://github.com/osuosl/packer-templates
* https://github.com/justmeandopensource/kubernetes
