#!/usr/bin/env bash
# configure firewall
ufw allow 22/tcp
ufw allow 6443/tcp
ufw allow 2379/tcp
ufw allow 2380/tcp
ufw allow 8080/tcp
ufw allow 10248/tcp
ufw allow 10250/tcp
ufw allow 10259/tcp
ufw allow 10257/tcp
# enable firewall
ufw enable

mkdir -p /etc/kubernetes/pki
cp -r /home/adminlocal/kubernetes/pki/ /etc/kubernetes/
chown -R root:root /etc/kubernetes/pki/
chmod -R 600 /etc/kubernetes/pki/

# initialize cluster
kubeadm config images pull --image-repository kuberegistry.dev.local
kubeadm init --skip-phases certs --config /home/adminlocal/kubernetes/kubeadm-init-config.yaml

# setup access kubectl access to cluster
scp /etc/kubernetes/admin.conf adminlocal@kubeadmin.dev.local:/home/adminlocal/.kube/config
