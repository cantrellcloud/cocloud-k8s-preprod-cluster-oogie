mkdir -p /etc/kubernetes/pki
cp -r /home/adminlocal/kubernetes/pki/ /etc/kubernetes/
chown -R root:root /etc/kubernetes/pki/
chmod -R 600 /etc/kubernetes/pki/

# initialize cluster
kubeadm config images pull --image-repository offline-registry.dev.local
kubeadm init --skip-phases certs --config /home/adminlocal/kubernetes/kubeadm-init-config.yaml

# setup access kubectl access to cluster
scp /etc/kubernetes/admin.conf adminlocal@kubeadmin.dev.local:/home/adminlocal/.kube/config
