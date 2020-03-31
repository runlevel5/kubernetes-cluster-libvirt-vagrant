## Kubernetes Cluster with libvirt/kvm on Linux ppc64le

Have you just picked up k8s? Struggling to get minikube up running on Linux ppc64le? Well so am I. The support
for Linux ppc64le is poor in k8s world so I code up a way to bring up a local k8s cluster with 1 master and 2 workers
with libvirt/kvm. This cluster is intended for learning and local development. DO NOT use for production.

### Prerequisites

* POWER9-based workstation running Linux ppc64le (for example Raptor CS Blackbird running Fedora 32 PPC64LE)
* packer
* vagrant
* vagrant-libvirt

### Get started

1. Build vagrant box:

```
cd packer && packer build ubuntu-18.04-ppc64le.json
```

2. Add vagrant box:

```
vagrant box add --name 'local/ubuntu-1804-k8s' box/ubuntu-1804-ppc64le.box
```

3. Orchestrate cluster:

```
cd vagrant && vagrant up
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
