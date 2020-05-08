#!/bin/bash
set -e

# Join worker nodes to the Kubernetes cluster
echo "Join node to Kubernetes Cluster"

apt-get install -q -y sshpass
sshpass -p "ubuntu" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@kmaster.example.com:/home/ubuntu/join_cluster.sh /home/ubuntu/join_cluster.sh
bash /home/ubuntu/join_cluster.sh
