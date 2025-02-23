mkdir -p /etc/kubernetes/pki
cp -r /home/kadmin/kubernetes/pki/ /etc/kubernetes/
chown -R root:root /etc/kubernetes/pki/
chmod -R 600 /etc/kubernetes/pki/

# initialize cluster
kubeadm config images pull --image-repository kuberegistry.k8.cantrellcloud.net
kubeadm init --skip-phases certs --config /home/kadmin/kubernetes/kubeadm-init-config.yaml

# setup access kubectl access to cluster
scp /etc/kubernetes/admin.conf kadmin@kubeadmin.k8.cantrellcloud.net:/home/kadmin/.kube/config
