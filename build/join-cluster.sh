#!/usr/bin/env bash
# configure firewall
#ufw allow 22/tcp
#ufw allow 80/tcp
#ufw allow 111/tcp
#ufw allow 2623/tcp
#ufw allow 179/tcp
#ufw allow 443/tcp
#ufw allow 5473/tcp
#ufw allow 7472/tcp
#ufw allow 7472/udp
#ufw allow 7473/tcp
#ufw allow 7473/udp
#ufw allow 7946/tcp
#ufw allow 7946/udp
#ufw allow 8181/tcp
#ufw allow 8443/tcp
#ufw allow 10250/tcp
#ufw allow 10256/tcp
#ufw allow 30000:32767/tcp
# enable firewall
#ufw --force enable
echo disable firewall...
ufw --force disable
echo
echo enable iscsi_tcp...
modprobe iscsi_tcp
echo
echo Joining cluster...
kubeadm join --config /home/kadmin/kubernetes/kubeadm-join-config.yaml
