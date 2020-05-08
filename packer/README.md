## Build libvirt vagrant box

Make sure you have the latest version of `packer`.

1. Build vagrant box:

```
cd packer && packer build ubuntu-18.04-k8s-<arch>.json
```

2. Add vagrant box:

```
vagrant box add --name 'local/ubuntu-1804-k8s' box/ubuntu-1804-<arch>-k8s.box
```

3. Now you could use this image in `Vagrantfile`:

```
Vagrant.configure("2") do |config|
  config.vm.box = "local/ubuntu-1804-k8s"
end
```
