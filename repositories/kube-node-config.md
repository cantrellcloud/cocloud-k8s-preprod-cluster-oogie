###############################################################################
##
## Create Image using VMware Workstation
##
## https://support.broadcom.com/group/ecx/productfiles?subFamily=VMware%20Workstation%20Player&displayGroup=VMware%20Workstation%20Player%2017&release=17.6.2&os=&servicePk=526674&language=EN
##
##

vm name: kubeimg24041

administrator: adminlocal
password: S1airarose!895


192.168.69.120 
192.168.69.121 k8dev-wkr01

do not enable kubelet service until after cloning
add all firewall allow rules then prune after cloning
disable firewall
do not add aliases until after cloning

*Before cloning

apt update && sudo apt upgrade -y

- Remove unnecessary files and packages to reduce the size of the clone:
sudo apt autoremove -y
sudo apt clean

- Verify the health of your disks to avoid cloning errors:
sudo smartctl -a /dev/sda

sudo rm -rf /var/log/*
sudo rm -rf /tmp/*

shutdown
export to OVF

###############################################################################
##
## Clean and configure cloned nodes and add to cluster
##
##

# run as root
sudo -i

# Change hostname and machine-id
```bash
hostnamectl set-hostname newhostname
rm /etc/machine-id
systemd-machine-id-setup
```

# Update networking

- Disable/Enable the cloud-init network configuration file:
cd /etc/cloud/cloud.cfg.d/
sudo cp -r /etc/cloud/cloud.cfg.d/ /etc/cloud/cloud.cfg.d.backup/

echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg


# Set static IP address
/etc/netplan

network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enx00e04c680202:
      addresses:
        - 192.168.200.100/24
        - 169.254.1.100/24
      routes:
       - to: default
         via: 192.168.200.220
      nameservers:
        addresses:
          - 8.8.8.8   # Add your DNS server IP address
          - 8.8.4.4   # Add another DNS server IP address

sudo netplan try
ping gateway
sudo kubeadm reset -f
reboot

# Verify cloud-init is disabled
sudo cat /var/log/cloud-init.log | grep -i network
Look for lines indicating that network configuration is disabled.


- connect via ssh and sudo

# Set Home folder permissions
chmod -R 750 /home/adminlocal/
chown -R adminlocal:adminlocal /home/adminlocal/
chmod -R a-x+X /home/adminlocal/

# set NTP client
tee /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=10.231.1.34
EOF

systemctl restart systemd-timesyncd
timedatectl timesync-status

# update containerd config.toml file to use correct sandbox_image
sed -i 's/pause:3.8/pause:3.10/' /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml


# Hosts file on all Kube nodes

```bash
tee /etc/hosts <<EOF
# LocalHost
127.0.0.1 localhost
# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
# Kubernetes Cluster Nodes
10.0.3.220 kubeadmin
10.0.3.220 kubeadmin.dev.local
10.0.3.221 kubectrl001
10.0.3.221 kubectrl001.dev.local
10.0.3.222 kubectrl002
10.0.3.222 kubectrl002.dev.local
10.0.3.223 kubectrl003
10.0.3.223 kubectrl003.dev.local
10.0.3.224 kubework001
10.0.3.224 kubework001.dev.local
10.0.3.225 kubework002
10.0.3.225 kubework002.dev.local
10.0.3.226 kubework003
10.0.3.226 kubework003.dev.local
10.0.3.229 offline-registry
10.0.3.229 offline-registry.dev.local
# Kubernetes API Endpoints
10.0.3.221 kubedev.dev.local
EOF
clear
cat /etc/hosts
```

# configure third-party certificates
 * run as normal user
sudo scp adminlocal@kubeadmin.dev.local:/home/adminlocal/certs/Kubernetes-Dev-CA.crt /usr/local/share/ca-certificates/Kubernetes-Dev-CA.crt
sudo scp adminlocal@kubeadmin.dev.local:/home/adminlocal/certs/Kubedev-Cluster-Kubernetes-CA.crt /usr/local/share/ca-certificates/Kubedev-Cluster-Kubernetes-CA.crt
sudo update-ca-certificates

# Disable systemd-networkd.service
sudo systemctl disable systemd-networkd.service

# remove Kubernetes configuation
sudo kubeadm reset
sudo rm -rf /etc/cni/net.d

# Reboot node
sudo reboot

# Add KubeAdmin ssh-key-id

- From kubeadmin priv workstation

ssh-copy-id adminlocal@<hostname>

ssh-copy-id adminlocal@kubectrl001
ssh-copy-id adminlocal@kubectrl002
ssh-copy-id adminlocal@kubectrl003
ssh-copy-id adminlocal@kubework001
ssh-copy-id adminlocal@kubework002
ssh-copy-id adminlocal@kubework003

adminlocal
S1airarose!895

###############################################################################
##
## Re-IP cluster master node
##
##
##

change the /etc/hosts of all nodes to the new addresses

cp -Rf /etc/kubernetes/ /etc/kubernetes-bak

*Replace the APIServer address of all configuration files in /etc/kubernetes.
oldip=172.16.255.15
newip=10.0.3.221
find . -type f | xargs grep $oldip
find . -type f | xargs sed -i "s/$oldip/$newip/"
find . -type f | xargs grep $newip

*Identify the certificate in /etc/kubernetes/pki that has the old IP address as the alt name.
cd /etc/kubernetes/pki
for f in $(find -name "*.crt"); do
openssl x509 -in $f -text -noout > $f.txt;
done

grep -Rl $oldip .
for f in $(find -name "*.crt"); do rm $f.txt; done

*Find the ConfigMap in the kube-system namespace that references the old IP.
configmaps=$(kubectl -n kube-system get cm -o name | \
awk '{print $1}' | \
cut -d '/' -f 2)

dir=$(mktemp -d)
for cf in $configmaps; do
kubectl -n kube-system get cm $cf -o yaml > $dir/$cf.yaml
done


*Find the ConfigMap in the kube-public namespace that references the old IP.
configmaps=$(kubectl -n kube-public get cm -o name | \
awk '{print $1}' | \
cut -d '/' -f 2)

dir=$(mktemp -d)
for cf in $configmaps; do
kubectl -n kube-public get cm $cf -o yaml > $dir/$cf.yaml
done

grep -Hn $dir/* -e $oldip

kubectl -n kube-system edit cm kubeadm-config
kubectl -n kube-system edit cm kube-proxy
kubectl -n kube-public edit cm cluster-info

*Delete the certificate and private key grep’d in step 3 and regenerate them.

cd /etc/kubernetes/pki
rm apiserver.crt apiserver.key
rm etcd/peer.crt etcd/peer.key
kubeadm init phase certs all

*Generate a new kubeconfig file.
cd /etc/kubernetes
rm -f admin.conf kubelet.conf controller-manager.conf scheduler.conf
kubeadm init phase kubeconfig all

*non-root account
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

*Restart services
systemctl restart containerd
systemctl restart kubelet
kubectl get nodes


###############################################################################
##
## Adding additional control-plane nodes
##
##
##

unable to add a new control plane instance to a cluster that doesn't have a stable controlPlaneEndpoint address

Please ensure that:
* The cluster has a stable controlPlaneEndpoint address.
* The certificates that must be shared among control plane instances are provided.


###############################################################################
#
# Misc.
#
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    ens32:
      addresses:
        - 10.0.3.x/22
      routes:
       - to: default
         via: 10.0.0.1
      nameservers:
        addresses:
          - 10.0.1.34
          - 10.231.1.34


