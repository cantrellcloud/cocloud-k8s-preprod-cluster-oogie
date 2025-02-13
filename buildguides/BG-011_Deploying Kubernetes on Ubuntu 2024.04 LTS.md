# Deploying Kubernetes on Ubuntu 2024.04 LTS Build Guide

COCloud K8s Development Cluster Oogie

```text
      _
      _\___
    /     \
   | <> <> |
    \ ( ) /
     |||||
 \---/|||\---/
     |||||
     |||||
    _/   \_   
<------------->
```

- [Deploying Kubernetes on Ubuntu 2024.04 LTS Build Guide](#deploying-kubernetes-on-ubuntu-202404-lts-build-guide)
  - [Introduction](#introduction)
  - [Infrastructure](#infrastructure)
    - [Resource Specifications](#resource-specifications)
    - [Logical Topology](#logical-topology)
    - [References, Tools, and Notes](#references-tools-and-notes)
      - [References](#references)
        - [Repositories](#repositories)
        - [URLs](#urls)
      - [Tools](#tools)
        - [Install Linux Integration Services (Hyper-V Tools)](#install-linux-integration-services-hyper-v-tools)
        - [Add Command Line Aliases](#add-command-line-aliases)
        - [Set NTP Client](#set-ntp-client)
        - [Update OS and Install Tools](#update-os-and-install-tools)
    - [Update hosts File](#update-hosts-file)
    - [Cluster Certificates](#cluster-certificates)
      - [Kubernetes Cluster Issuing Certificate Authority](#kubernetes-cluster-issuing-certificate-authority)
  - [Configure Container Runtime Environment](#configure-container-runtime-environment)
    - [Install Containerd](#install-containerd)
      - [Configure cgroup drivers](#configure-cgroup-drivers)
  - [Configure Cloned Machine](#configure-cloned-machine)
  - [Create and Configure Offline Registry](#create-and-configure-offline-registry)
    - [Install Helm](#install-helm)
      - [Install Helm Charts](#install-helm-charts)
    - [Install NFS Shares](#install-nfs-shares)
  - [Kubernetes Cluster Configuration, Initialization, Networking](#kubernetes-cluster-configuration-initialization-networking)
    - [Cluster Configuration](#cluster-configuration)
      - [KubeRegistry Configuration](#kuberegistry-configuration)
        - [Pull, Re-Tag, and Push Images](#pull-re-tag-and-push-images)
      - [Verify the MAC Address and product\_uuid](#verify-the-mac-address-and-product_uuid)
      - [IP Configuration](#ip-configuration)
      - [Disable systemd-networkd-wait-online](#disable-systemd-networkd-wait-online)
      - [Turn off swap now and make persistent across reboots](#turn-off-swap-now-and-make-persistent-across-reboots)
      - [Update firewall rules](#update-firewall-rules)
    - [Cluster Initialization](#cluster-initialization)
      - [Pull kubeadm config images](#pull-kubeadm-config-images)
      - [Initialize default configuration](#initialize-default-configuration)
      - [Modify the kubelet](#modify-the-kubelet)
    - [Cluster Networking](#cluster-networking)
      - [Install Calico network overlay](#install-calico-network-overlay)
    - [Verify Cluster Status](#verify-cluster-status)
    - [Add additional nodes to cluster and labels, taints, and tolerances](#add-additional-nodes-to-cluster-and-labels-taints-and-tolerances)

## Introduction

Kubernetes, often abbreviated as K8s, is an open-source platform designed to automate the deployment, scaling, and operation of application containers. It provides a robust framework to run distributed systems resiliently, handling scaling and failover for Enterprise applications, and providing deployment patterns for developers. Whether you're managing a few containers or scaling to thousands, Kubernetes offers the tools and capabilities to ensure your applications run smoothly and efficiently.

In this guide, we'll walk you through the essential steps to set up, configure, and deploy a single application on Kubernetes using VXLAN network features. We'll start with setting up a Kubernetes cluster, followed by configuring networking, necessary components and resources, and finally deploying the application. By the end of this guide, you'll have a solid understanding of the Kubernetes architecture and be well-equipped to begin containerizing applications in an Enterprise production environment.

## Infrastructure

### Resource Specifications

- Physical
  - Dell Precision 3260
    - 13th Gen Intel(R) Core(TM) i9-13900 2.00 GHz
    - 32GB RAM
    - Windows 11 Enterprise 24H2
- Virtual
  - Network
    - 10.0.69.32/27
  - Storage
    - NFS Share Server
    - NFS Share Clients
  - Compute
    - Administration
      - kubeadmin
      - kuberegistry
    - Cluster Control Plane
      - kubectrl01
      - kubectrl02
      - kubectrl03
    - Cluster Worker Plane
      - kubework01
      - kubework02
      - kubework03
- Virtual Machine Specifications
  - Hypervisor
    - Hyper-V on Windows 11 Enterprise 24H2
  - Compute
    - Kube Administration
      - 2 vCPUs
      - 3GB/4GB RAM Start/Max
      - 128GB Thin Provisioned HDD
      - Ubuntu 24.04 LTS Desktop Installation
    - Kube Registry
      - 2 vCPUs
      - 1GB/4GB RAM Start/Max
      - 128GB Thin Provisioned HDD
      - Ubuntu 24.04 LTS Minimal Installation
    - Kube Control/Worker Machines
      - 2 vCPUs
      - 1GB/4GB RAM Start/Max
      - 128GB Thin Provisioned HDD
      - Ubuntu 24.04 LTS Minimal Installation
  - Networking
    - Host VLAN
      - Nodes CIDR: 10.0.69.32/27
    - Cluster Networking
      - VXLAN
        - Pods CIDR: 172.16.69.32/27
        - Service CIDR: 172.16.68.64/26
- Assumptions & Dependencies
  - It is assumed that K8s is being deployed in an on-premises and offline laboratory environment to ensure strict configuration control.
  - It is assumed that all administration will be initiated or pushed to K8s cluster control and worker nodes. All commands should be done remotely unless directed otherwise.
  - It is assumed that the Intermediate Certificate Signing Request (CSR) generated by this deployment guide will be signed by an Enterprise Certificate Authority or other third-party CA for K8s cluster certificate services.
  - It is assumed that static software and YAML files can be transferred from a bastion host into the offline environment.
  - It is assumed that all containers and images will be pulled from the Internet when the bastion host is connected to the external network, tagged with offline URL, then pushed to the offline registry.
  - It is assumed that all containers and images, when the bastion host is connected to the internal lab network, will be pulled from the offline registry.

### Logical Topology

```text
   +===============================================================================================+
   |                                                                                               |
   |  +-----------------------------------------------------------------------------------------+  |
   |  | INGRESS (kube-vip)                                                                      |  |
   |  |                                                                                         |  |
   |  |     +----------------+            +-----------------+            +-----------------+    |  |
   |  |     | api.domain.tld |            | app1.domain.ltd |            | app2.domain.ltd |    |  |
   |  |     +----------------+            +-----------------+            +-----------------+    |  |
   |  |             |                              |                              |             |  |
   |  +-----------------------------------------------------------------------------------------+  |
   |                |                              |                              |                |
   |                |                              |                              |                |
   |  +---------------------------+  +---------------------------+  +---------------------------+  |
   |  |             |             |  |             |             |  |             |             |  |
   |  |  +---------------------+  |  |  +---------------------+  |  |  +---------------------+  |  |
   |  |  | SERVICE (ClusterIP) +  |  |  | SERVICE (ClusterIP) |  |  |  | SERVICE (ClusterIP) |  |  |
   |  |  +---------------------+  |  |  +---------------------+  |  |  +---------------------+  |  |
   |  |     |       |       |     |  |     |       |       |     |  |     |       |       |     |  |
   |  |     |       |       |     |  |     |       |       |     |  |     |       |       |     |  |
   |  |     \       |       /     |  |     \       |       /     |  |     \       |       /     |  |
   |  |  +-----+ +-----+ +-----+  |  |  +-----+ +-----+ +-----+  |  |  +-----+ +-----+ +-----+  |  |
   |  |  | POD | | POD | | POD |  |  |  | POD | | POD | | POD |  |  |  | POD | | POD | | POD |  |  |
   |  |  +-----+ +-----+ +-----+  |  |  +-----+ +-----+ +-----+  |  |  +-----+ +-----+ +-----+  |  |
   |  |                           |  |                           |  |                           |  |
   |  | CONTROL NODE              |  | WORKER NODE               |  | WORKER NODE               |  |
   |  +---------------------------+  +---------------------------+  +---------------------------+  |
   |                                                                                               |
   | KUBERNETES CLUSTER                                                                            |
   +===============================================================================================+
```

### References, Tools, and Notes

#### References

##### Repositories

- This is an all inclusive list of the repositories and configuration files used throughout this deployment

```text
raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
github.com/projectcalico/calico/releases/download/v3.29.1/calicoctl-linux-amd64
downloads.tigera.io/ee/binaries/v3.19.4/calicoctl
pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key
download.nerdctl.com/linux/ubuntu/gpg
download.nerdctl.com/linux/ubuntu
```

##### URLs

<https://github.com/containerd/nerdctl>
<https://github.com/containerd/containerd/blob/main/docs/getting-started.md>

#### Tools

##### Install Linux Integration Services (Hyper-V Tools)

```bash
echo 'hv_vmbus' >> /etc/initramfs-tools/modules
echo 'hv_storvsc' >> /etc/initramfs-tools/modules
echo 'hv_blkvsc' >> /etc/initramfs-tools/modules
echo 'hv_netvsc' >> /etc/initramfs-tools/modules
apt update && apt upgrade -y && apt -y install linux-virtual linux-cloud-tools-virtual linux-tools-virtual
update-initramfs -u
reboot
```

##### Add Command Line Aliases

- For frequently used commands
  - Not required on K8 control/worker nodes

```bash
tee ~/.bash_aliases <<EOF
alias k=kubectl
alias kg='kubectl get'
alias kd='kubectl describe'
alias ka='kubectl apply'
alias kdelf='kubectl delete -f'
alias kl='kubectl logs'
alias kgall='kubectl get all -A'
alias ktn='kubectl top node'
alias ktp='kubectl top pod'
alias n=nerdctl
alias nil='nerdctl image ls'
alias ncl='nerdctl container ls'
alias nirm='nerdctl image rm'
alias ncrm='nerdctl container rm'
alias ncstart='nerdctl container start'
alias ncstop='nerdctl container stop'
EOF

source ~/.bash_aliases
```

##### Set NTP Client

```bash
# The following will replace current network configuration

tee /etc/systemd/timesyncd.conf <<EOF
[Time]
NTP=time.cantrelloffice.cloud
EOF

systemctl restart systemd-timesyncd
wait 1500
timedatectl timesync-status
```

##### Update OS and Install Tools

```bash
### Download public signing key for kubernetes repositories
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

### add kubernetes apt repository
#This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

### update apt index and install required packages
apt update && apt upgrade -y
apt install -y kubelet kubeadm kubectl openssl ufw vim apt-transport-https ca-certificates curl gpg net-tools gnupg
apt-mark hold kubelet kubeadm kubectl
apt update && apt upgrade -y

### enable kubelet service
# the kubelet will restart every few seconds, as it waits in a crashloop for kubeadm to tell it what to do.

# hostname: kubeimage
systemctl enable --now kubelet

# hostname: kubeadmin
systemctl disable kubelet
```

- Generate SSH Key Id
  - Run as non-root user

```bash
### generate ssh-key-id
ssh-keygen -t rsa -b 4096

### copy ssh-key-id to hosts
ssh-copy-id kdmin@<hostname>
```

### Update hosts File

```bash
vi /etc/hosts
```

```bash
10.0.69.51 kubectrl01.k8.cantrellcloud.net
10.0.69.52 kubectrl02.k8.cantrellcloud.net
10.0.69.53 kubectrl03.k8.cantrellcloud.net
10.0.69.54 kubework01.k8.cantrellcloud.net
10.0.69.55 kubework02.k8.cantrellcloud.net
10.0.69.56 kubework03.k8.cantrellcloud.net
10.0.69.57 kubework04.k8.cantrellcloud.net
10.0.69.58 kubework05.k8.cantrellcloud.net
10.0.69.59 kubework06.k8.cantrellcloud.net
10.0.69.60 kubeimage.k8.cantrellcloud.net
10.0.69.61 kuberegistry.k8.cantrellcloud.net
10.0.69.62 kubeadmin.k8.cantrellcloud.net
10.0.69.51 kubectrl01.cantrellcloud.net
10.0.69.52 kubectrl02.cantrellcloud.net
10.0.69.53 kubectrl03.cantrellcloud.net
10.0.69.54 kubework01.cantrellcloud.net
10.0.69.55 kubework02.cantrellcloud.net
10.0.69.56 kubework03.cantrellcloud.net
10.0.69.57 kubework04.cantrellcloud.net
10.0.69.58 kubework05.cantrellcloud.net
10.0.69.59 kubework06.cantrellcloud.net
10.0.69.60 kubeimage.cantrellcloud.net
10.0.69.61 kuberegistry.cantrellcloud.net
10.0.69.62 kubeadmin.cantrellcloud.net
```

### Cluster Certificates

This deployment uses a custom PKI configuration that will generate a Certificate Signing Request (CSR) to be signed by an external Root Certificate Authority. The certificate authority created by this deployment will be a Subordinate CA used for signing all certificates requested and signed for use solely by the deployed Kubernetes cluster.

#### Kubernetes Cluster Issuing Certificate Authority

- The Certificate Authority should be installed on a PRIV access Ubuntu management workstation
- Create Openssl configuration file to create subordinate CA certificate request
  - Generating a Certificate Signing Request (CSR) for a Subject Alternative Name (SAN) certificate using OpenSSL with a configuration file involves a few steps. Here's a guide to help you through the process:

- Create the CA Request on Ubuntu
  - Configure Your CA: Update your OpenSSL configuration to use the new CA certificate and key

- Create the CA folder structure

```bash
mkdir /opt/ca
mkdir /opt/ca/certs
mkdir /opt/ca/crl
mkdir /opt/ca/newcerts
mkdir /opt/ca/private
mkdir /opt/ca/requests
touch /opt/ca/index.txt
echo 1000 > /opt/ca/serial
```

- Set strict permissions of the CA folder

```bash
chmod 600 /opt/ca
```

- Create Openssl configuration file to create CA certificate request

```bash
tee /opt/ca/requests/cacert-openssl.cnf <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir = /opt/ca
certs = $dir/certs
crl_dir = $dir/crl
database = $dir/index.txt
new_certs_dir = $dir/newcerts
certificate = $dir/cacert.pem
serial = $dir/serial
crlnumber = $dir/crlnumber
crl = $dir/crl.pem
private_key = $dir/private/cakey.pem
RANDFILE = $dir/private/.rand
default_days = 3650

[ req ]
default_bits = 4096
default_md = sha256
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
string_mask = utf8only

[ req_distinguished_name ]
countryName = Country Name (2 letter code)
countryName_default = US
stateOrProvinceName = State or Province Name (full name)
stateOrProvinceName_default = Florida
localityName = Locality Name (eg, city)
localityName_default = New Port Richey
organizationName = Organization Name (eg, company)
organizationName_default = Cantrell Cloud ES
commonName = Common Name (eg, YOUR name)
commonName_default = Cantrell Cloud Kubernetes Certificate Authority 01

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical,CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF
```

```bash
tee /opt/ca/requests/subca-cacert-openssl.cnf <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir = /opt/ca
certs = $dir/certs
crl_dir = $dir/crl
database = $dir/index.txt
new_certs_dir = $dir/newcerts
certificate = $dir/cacert.pem
serial = $dir/serial
crlnumber = $dir/crlnumber
crl = $dir/crl.pem
private_key = $dir/private/cakey.pem
RANDFILE = $dir/private/.rand
default_days = 3650

[ req ]
default_bits = 4096
default_md = sha256
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
string_mask = utf8only

[ req_distinguished_name ]
countryName = Country Name (2 letter code)
countryName_default = US
stateOrProvinceName = State or Province Name (full name)
stateOrProvinceName_default = Florida
localityName = Locality Name (eg, city)
localityName_default = New Port Richey
organizationName = Organization Name (eg, company)
organizationName_default = Cantrell Cloud ES
commonName = Common Name (eg, YOUR name)
commonName_default = Cantrell Cloud Kubernetes Issuing Certificate Authority 01

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical,CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF
```

- Generate CA/Root Certificate Request

- Generate CA Private Key:

```bash
openssl genrsa \
  -aes256 \
  -out /opt/ca/private/cakey.pem \
  4096
```

```bash
# subj Cantrell Cloud Kubernetes Certificate Authority 01
openssl req -new -x509 \
  -days 3650 \
  -extensions v3_ca \
  -out /opt/ca/cacert.pem \
  -key /opt/ca/private/cakey.pem \
  -config /opt/ca/requests/cacert-openssl.cnf
```

- Generate SubCA/Root Certificate Request
  - To be installed on kubeadmin.k8.cantrellcloud.net

- Generate subCA Private Key:

```bash
openssl genrsa \
  -aes256 \
  -out /opt/ca/private/subca-cakey.pem \
  4096
```

```bash
# subj Cantrell Cloud Kubernetes Issuing Certificate Authority 01





openssl req -new \
  -extensions v3_ca \
  -out /opt/ca/requests/subca-cacert.csr \
  -key /opt/ca/private/subca-cakey.pem \
  -config /opt/ca/requests/subca-cacert-openssl.cnf

openssl x509 -req \
  -in /opt/ca/requests/subca-cacert.csr \
  -CA /opt/ca/cacert.pem \
  -CAkey /opt/ca/private/cakey.pem \
  -out /opt/ca/certs/subca-cacert.crt \
  -extensions v3_ca \
  -extfile /opt/ca/requests/cacert-openssl.cnf

cat /opt/ca/certs/subca-cacert.crt /opt/ca/private/subca-cakey.pem > /opt/ca/certs/subca-cacert.pem

```

-------------------------------------------------------------------------------

- Copy new certificate to ca-certificates and update ca-certificates

```bash
cp /opt/ca/certs/subca-cacert.pem \
  /usr/local/share/ca-certificates/Cantrell-Cloud-Kubernetes-Certificate-Authority-01.crt
cp /opt/ca/cacert.pem \
  /usr/local/share/ca-certificates/Cantrell-Cloud-Kubernetes-Issuing-Certificate-Authority-01.crt
update-ca-certificates --verbose
```

Copy cocloud-kube-cluster-subCA-01.crt to all COCloud Kubernetes Cluster hosts, control nodes, and worker nodes

```bash
scp /usr/local/share/ca-certificates/Cantrell-Cloud-Kubernetes-Certificate-Authority-01.crt \
  kadmin@kubeimage.k8.cantrellcloud.net:/home/kadmin/kubeconf/certs/Cantrell-Cloud-Kubernetes-Certificate-Authority-01.crt
scp /usr/local/share/ca-certificates/Cantrell-Cloud-Kubernetes-Issuing-Certificate-Authority-01.crt \
  kadmin@kubeimage.k8.cantrellcloud.net:/home/kadmin/kubeconf/certs/Cantrell-Cloud-Kubernetes-Issuing-Certificate-Authority-01.crt
```

- Create KubeRegistry SAN Configuration File
  - This file can also be used as a template for server certificates

```bash
# kuberegistry certificate configuration
tee /opt/ca/requests/kuberegistry-san.cnf <<EOF
[req]
default_bits           = 2048
default_md             = sha256
distinguished_name     = req_distinguished_name
req_extensions         = req_ext
prompt                 = no
string_mask            = utf8only

[req_distinguished_name]
countryName            = US
stateOrProvinceName    = Florida
localityName           = New Port Richey
organizationName       = Cantrell Cloud ES
organizationalUnitName = InfoSys
commonName             = kuberegistry.k8.cantrellcloud.net

[req_ext]
extendedKeyUsage       = serverAuth
keyUsage               = keyEncipherment, dataEncipherment
subjectAltName         = @alt_names

[alt_names]
DNS.1                  = kuberegistry.k8.cantrellcloud.net
DNS.2                  = kuberegistry.cantrellcloud.net
IP.1                   = 10.0.69.61
EOF

# kubeadmin certificate configuration
tee /opt/ca/requests/kubeadmin-san.cnf <<EOF
[req]
default_bits           = 2048
default_md             = sha256
distinguished_name     = req_distinguished_name
req_extensions         = req_ext
prompt                 = no
string_mask            = utf8only

[req_distinguished_name]
countryName            = US
stateOrProvinceName    = Florida
localityName           = New Port Richey
organizationName       = Cantrell Cloud ES
organizationalUnitName = InfoSys
commonName             = kubeadmin.k8.cantrellcloud.net

[req_ext]
extendedKeyUsage       = serverAuth
keyUsage               = keyEncipherment, dataEncipherment
subjectAltName         = @alt_names

[alt_names]
DNS.1                  = kubeadmin.k8.cantrellcloud.net
DNS.2                  = kubeadmin.cantrellcloud.net
IP.1                   = 10.0.69.62
EOF
```

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------

- Server/Client Certificates
  - Create certificate request
- This process will create a CSR that includes the SANs specified in the configuration file

```bash
# kuberegistry certificate
cd /opt/ca/requests
openssl req \
  -out kuberegistry.csr \
  -newkey rsa:2048 \
  -nodes \
  -keyout /opt/ca/private/kuberegistry-key.pem \
  -extensions req_ext \
  -config kuberegistry-san.cnf

openssl ca \
  -in kuberegistry.csr \
  -out /opt/ca/certs/kuberegistry.crt \
  -extensions req_ext \
  -extfile kuberegistry-san.cnf

cat /opt/ca/certs/kuberegistry.crt /opt/ca/private/kuberegistry-key.pem > /opt/ca/certs/kuberegistry.pem
```

```bash
# kubeadmin certificate
cd /opt/ca/requests
openssl req \
  -out kubeadmin.csr \
  -newkey rsa:2048 \
  -nodes \
  -keyout /opt/ca/private/kubeadmin-key.pem \
  -extensions req_ext \
  -config kubeadmin-san.cnf

openssl ca \
  -in kubeadmin.csr \
  -out /opt/ca/certs/kubeadmin.crt \
  -extensions req_ext \
  -extfile kubeadmin-san.cnf

cat /opt/ca/certs/kubeadmin.crt /opt/ca/private/kubeadmin-key.pem > /opt/ca/certs/kubeadmin.pem
```

-------------------------------------------------------------------------------

## Configure Container Runtime Environment

- Only required on Kubernetes control or worker nodes

- create containerd.conf

```bash
tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
```

- create kube.conf

```bash
tee /etc/sysctl.d/kube.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system
```

- Verify that net.ipv4.ip_forward is set to 1 with:

```bash
sysctl net.ipv4.ip_forward

```

### Install Containerd

- Download containerd from <https://github.com/containerd/containerd/releases>
- Download runc.amd64 from <https://github.com/opencontainers/runc/releases>
- Download cni-plugins from <https://github.com/containernetworking/plugins/releases>
- Download containerd.service from <https://raw.githubusercontent.com/containerd/containerd/main/containerd.service>
- Download nerdctl from <https://github.com/containerd/nerdctl/releases>

```bash
# containerd binaries
tar Cxzvf /usr/local /home/kadmin/kubeconf/containerd/containerd-2.0.2-linux-amd64.tar.gz

# runc binaries
install -m 755 /home/kadmin/kubeconf/containerd/runc.amd64 /usr/local/sbin/runc

# cni-plugins
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin /home/kadmin/kubeconf/containerd/cni-plugins-linux-amd64-v1.6.2.tgz

# containerd.service
mkdir -p /usr/local/lib/systemd/system
cp /home/kadmin/kubeconf/containerd/containerd.service /usr/local/lib/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd

# nerdctl
tar Cxzvvf /usr/local/bin /home/kadmin/kubeconf/containerd/nerdctl-2.0.3-linux-amd64.tar.gz

# Configure service to start automatically & check to make sure it is running

systemctl restart containerd
systemctl enable containerd
systemctl status containerd
```

#### Configure cgroup drivers

Note: I did not configure the following

- configure the system so it starts using systemd as cgroup

```bash
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1
```

- verify containerd config file - still need to work on this

```bash
cat /etc/containerd/config.toml
```

```text
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true
```

- Confirm cgroup v2

```bash
cat /etc/default/grub | grep systemd.unified_cgroup_hierarchy
```

- Enable non-root cpu, cpuset, and i/o delegation - run as non-root user on k8s-controllers

```bash
sudo mkdir -p /etc/systemd/system/user@.service.d
cat <<EOF | sudo tee /etc/systemd/system/user@.service.d/delegate.conf
[Service]
Delegate=cpu cpuset io memory pids
EOF
sudo systemctl daemon-reload

cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/cgroup.controllers  - run as non-root user on k8s-controllers
```

-------------------------------------------------------------------------------

## Configure Cloned Machine

- After cloning

```bash
hostnamectl set-hostname [nethostname]
rm /etc/machine-id
systemd-machine-id-setup
```

- Change IP Settings

-------------------------------------------------------------------------------

## Create and Configure Offline Registry

```bash
# Start/Create Registry Container
# run container
mkdir -p /opt/kuberegistry
mkdir -p /opt/kuberegistry/certs
mkdir -p /opt/kuberegistry/data
cd /opt/kuberegistry
cp /home/kadmin/kubeconf/certs/kuberegistry.crt /opt/kuberegistry/certs/kuberegistry.crt
cp /home/kadmin/kubeconf/certs/kuberegistry-key.pem /opt/kuberegistry/certs/kuberegistry-key.pem
tee build.sh <<EOF
#!/usr/bin/env bash
nerdctl run -d \
 --restart always \
 --name kuberegistry \
 -v "$(pwd)"/certs:/certs \
 -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
 -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/kuberegistry.crt \
 -e REGISTRY_HTTP_TLS_KEY=/certs/kuberegistry-key.pem \
 -e /data:/var/lib/registry \
 -p 443:443 \
 registry:2
EOF
chmod +x /opt/kuberegistry/build.sh
```

-------------------------------------------------------------------------------

### Install Helm

```bash
  curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
  apt-get install apt-transport-https --yes
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
  apt-get update
  apt-get install helm
```

#### Install Helm Charts

- Pi-Hole helm chart
  
```bash
  helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes/
  helm upgrade -i pihole mojo2600/pihole -f values-pihole.yaml
```

### Install NFS Shares

- On NFS Export server
  
```bash
  apt-get install nfs-kernel-server -y
  mkdir -p /opt/nfsshares
  mkdir -p /srv/nfs4/nfsshares
  mount --bind /opt/nfsshares /srv/nfs4/nfsshares
  vi /etc/fstab
    /opt/nfsshares /srv/nfs4/nfsshares none bind 0 0
  vi /etc/exports
    /shared/folder *(rw,no_root_squash,insecure,async,no_subtree_check,anonuid=1000,anongid=1000)
  exportfs -ar
  exportfs -v
  ufw allow 2049/tcp
  ufw allow 2049/udp
  reboot
```
  
- On each Worker Node
  
```bash
  apt-get install nfs-common -y
  mkdir /opt/nfsshares
  mount -t nfs -o vers=4 10.0.69.41:/srv/nfs4/nfsshares /opt/nfsshares
  df -h
  vi /etc/fstab
    10.0.69.41:/srv/nfs4/nfsserver /opt/nfsshares nfs defaults,timeo=900,retrans=5,_netdev 0 0
  reboot
```

-------------------------------------------------------------------------------

## Kubernetes Cluster Configuration, Initialization, Networking

### Cluster Configuration

#### KubeRegistry Configuration

##### Pull, Re-Tag, and Push Images

- Pull Images

```bash
for image in `cat /home/kadmin/kubeconf/kuberegistry/offline-images.list`; do echo $image; nerdctl pull $image; done
```

- Re-Tag Images

```bash
for image in `cat /home/kadmin/kubeconf/kuberegistry/offline-images.list`; do echo $image; nerdctl tag $image `echo $image | sed -E 's#^[^/]+/#kuberegistry.k8.cantrellcloud.net/#'`; done
```

- Push Images

```bash
for image in `cat /home/kadmin/kubeconf/kuberegistry/offline-images.list`; do echo $image; nerdctl push `echo $image | sed -E 's#^[^/]+/#kuberegistry.k8.cantrellcloud.net/#'`; done
```

- Verify Images are Pushed

```bash
curl https://offline-registry.dev.local/v2/_catalog
```

#### Verify the MAC Address and product_uuid

You can get the MAC address of the network interfaces using the command

```bash
 ip link
 ```

 or

```bash
 ifconfig -a
```

#### IP Configuration

- Set Interfaces - only if required

```bash
# The following will replace current network configuration
# Be sure to change required data before running tee command

tee /etc/netplan/50-cloud-init.yaml <<EOF
network:
    ethernets:
        eth0:
            addresses:
            - 10.0.69.51/27
            nameservers:
                addresses:
                - 172.16.69.71
                - 172.16.69.72
                search:
                - cantrellcloud.net
                - cantrelloffice.cloud
                - cantrell.cloud
            routes:
            -   to: default
                via: 10.0.69.33
        eth1: {}
    version: 2
    vlans:
        eth1.10:
            id: 10
            link: eth1
        eth1.101:
            id: 101
            link: eth1
EOF

netplan try
```

- The product_uuid can be checked by using the command

```bash
cat /sys/class/dmi/id/product_uuid
```

#### Disable systemd-networkd-wait-online

```bash
/lib/systemd/system/systemd-networkd-wait-online.service

- add TimeoutStartSec=5sec under the [Service] section, e.g.:

[Service]
Type=oneshot
ExecStart=/lib/systemd/systemd-networkd-wait-online
RemainAfterExit=yes
TimeoutStartSec=5sec
```

#### Turn off swap now and make persistent across reboots

```bash
swapoff-a
```

- Make Persistent across reboot; look for swap in --/etc/fstab and put a # in front of it

```bash
vi /etc/fstab
```

#### Update firewall rules

- Control Plane rules

```bash
# set rules
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
# check firewall status
ufw status verbose
```

- Worker Nodes rules

```bash
# set rules
ufw allow 22/tcp
ufw allow 5473/tcp
ufw allow 10250/tcp
ufw allow 10256/tcp
ufw allow 30000:32767/tcp
# enable firewall
ufw enable
# check firewall status
ufw status verbose
```

-------------------------------------------------------------------------------

### Cluster Initialization

Use scripts to create a cluster configuration and build cluster master control and 3 worker nodes

-------------------------------------------------------------------------------

#### Pull kubeadm config images

- Pull kubeadm default config - only on one of the controllers

```bash
sysctl --system
kubeadm config images pull
```

#### Initialize default configuration

- Initialize default configuration
  - If building an image, this is a good time to take snapshot 1

```bash
kubeadm init
```

- - Perform next commands as a regular user

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### Modify the kubelet

ConfigMap
Should be set, run command to verify cgroupDriver: systemd

```bash
kubectl edit cm kubelet-config -n kube-system
```

- Node Labels

```bash
kubectl label node kubectrl02 node-role.kubernetes.io/control-plane=
kubectl label node kubework01 node-role.kubernetes.io/worker=
```

### Cluster Networking

#### Install Calico network overlay

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
curl https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
kubectl create -f custom-resources.yaml
```

- Initialize network overlay

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

- may take a few minutes for all nodes in the cluster to spin up all the networking nodes and **report ready**
  - You can watch by entering the following command

```bash
watch kubectl get pods -n calico-system
```

- Configure NSX overlay
  - It is best practice to use manifest (yaml) files which will be added in a future release
  - For now, create config.yaml files for each of the following IPPools to enable NSX overlay

```yaml
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: ippool-vxlan-dev-internal-subnets
  namespace: dev-internal
spec:
  allowedUses:
  - Workload
  - Tunnel
  blockSize: 26
  cidr: 192.168.69.0/24
  ipipMode: Always
  natOutgoing: true
  nodeSelector: all()
  vxlanMode: CrossSubnet
```

```yaml
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: ippool-vxlan-dev-external-subnets
  namespace: dev-external
spec:
  allowedUses:
  - Workload
  - Tunnel
  blockSize: 26
  cidr: 192.168.68.0/24
  ipipMode: Always
  natOutgoing: true
  nodeSelector: all()
  vxlanMode: CrossSubnet
```

### Verify Cluster Status

```bash
kubectl get nodes
```

- If building an image, this is a good time to take snapshot 2

### Add additional nodes to cluster and labels, taints, and tolerances

- To join nodes, you must fist have a key
  - Copy/paste the displayed output to other nodes that are ready to be added to the cluster

```bash
kubeadm token create --print-join-command
```

- On each worker node as a regular user

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

- Label nodes

```bash
kubectl label node nodename key=value
```

- To bash into a pod

```bash
k exec --stdin --tty dev-intdmz-linux-test-65bf85b85d-lnnhw --namespace=dev-external -- /bin/bash
```
