#!/bin/bash

swapoff -a

systemctl stop ufw
systemctl disable ufw
iptables -F

apt-get install curl -y
curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL=v1.22.6+rke2r1 INSTALL_RKE2_TYPE="server" sh -

systemctl enable rke2-server.service
systemctl start rke2-server.service

echo "rke2-server started"

sleep 5m

systemctl status rke2-server.service

mkdir $HOME/.kube
cp /etc/rancher/rke2/rke2.yaml $HOME/.kube/config
cat /var/lib/rancher/rke2/server/node-token
