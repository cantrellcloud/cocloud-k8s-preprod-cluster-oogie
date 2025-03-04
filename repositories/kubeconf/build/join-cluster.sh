#!/usr/bin/env bash
# configure firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 179/tcp
ufw allow 443/tcp
ufw allow 5473/tcp
ifw allow 8443/tcp
ufw allow 10250/tcp
ufw allow 10256/tcp
ufw allow 30000:32767/tcp
# enable firewall
ufw enable

mkdir -p /mnt/k8data
kubeadm join --config /home/kadmin/kubernetes/kubeadm-join-config.yaml
