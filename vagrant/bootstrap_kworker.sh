#!/bin/bash
set -e

# Join worker nodes to the Kubernetes cluster
echo "Join node to Kubernetes Cluster"

apt-get install -q -y sshpass
sshpass -p "vagrant" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no vagrant@kmaster.example.com:/home/vagrant/join_cluster.sh /home/vagrant/join_cluster.sh
bash /home/vagrant/join_cluster.sh
