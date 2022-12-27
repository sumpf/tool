#!/bin/bash

swapoff -a

systemctl stop ufw
systemctl disable ufw
iptables -F

apt-get install curl -y
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -

mkdir -p /etc/rancher/rke2/

systemctl enable rke2-agent.service
systemctl start rke2-agent.service
journalctl -u rke2-agent -f

