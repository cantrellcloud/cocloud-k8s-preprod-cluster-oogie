#!/usr/bin/env bash
# configure firewall
#ufw allow 22/tcp
#ufw allow 111/tcp
#ufw allow 179/tcp
#ufw allow 2623/tcp
#ufw allow 6443/tcp
#ufw allow 2379/tcp
#ufw allow 2380/tcp
#ufw allow 7472/tcp
#ufw allow 7472/udp
#ufw allow 7473/tcp
#ufw allow 7473/udp
#ufw allow 7946/tcp
#ufw allow 7946/udp
#ufw allow 8080/tcp
#ufw allow 8181/tcp
#ufw allow 8443/tcp
#ufw allow 10248/tcp
#ufw allow 10250/tcp
#ufw allow 10259/tcp
#ufw allow 10256/tcp
#ufw allow 10257/tcp
# enable firewall
#ufw --force enable
# disable firewall
echo disable firewall...
ufw --force disable
# initialize cluster
echo Initializing cluster...
# create directories
mkdir -p /etc/kubernetes/pki
cp -r /home/kadmin/kubernetes/pki/ /etc/kubernetes/
chown -R root:root /etc/kubernetes/pki/
chmod -R 600 /etc/kubernetes/pki/

# initialize cluster
kubeadm config images pull --image-repository kuberegistry.k8.cantrellcloud.net
kubeadm init --skip-phases certs --config /home/kadmin/kubernetes/kubeadm-init-config.yaml

# setup access kubectl access to cluster
scp /etc/kubernetes/admin.conf kadmin@kubeadmin.k8.cantrellcloud.net:/home/kadmin/.kube/config
