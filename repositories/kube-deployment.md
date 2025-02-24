# Deploy Kubernetes in PreProd Environment

## Command Aliases

```bash
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
alias ncl='nerdctl container rm'
alias ncstart='nerdctl container start'
alias ncstop='nerdctl container stop'
alias npl='nerdctl pull'
alias nph='nerdctl push'
```

###############################################################################
# Create Kubernetes Certificate Authority and Generate Certificates
#
sudo -i
mkdir /opt/ca
mkdir /opt/copinekubeca01/certs
mkdir /opt/copinekubeca01/crl
mkdir /opt/copinekubeca01/newcerts
mkdir /opt/copinekubeca01/private
mkdir /opt/copinekubeca01/requests
touch /opt/copinekubeca01/index.txt
echo '1000' /opt/copinekubeca01/serial
chmod 600 /opt/ca
cd /opt/ca
openssl genrsa -aes256 -out private/cakey.pem 4096
openssl req -new -x509 -key /opt/copinekubeca01/cakey.pem -out cacert.pem -days 3650
vi /usr/lib/ssl/openssl.cnf # [CA_default] dir = /opt/ca # Where everything is kept
cd /opt/requests

# create certificate request
openssl req 
 -out offline-registry.csr 
 -newkey rsa:2048 
 -nodes 
 -keyout /opt/copinekubeca01/private/offline-registry-key.pem 
 -extensions req_ext 
 -config offline-registry-san.cnf

# get certificate request signed by CA
openssl ca \
 -in offline-registry.csr \
 -out offline-registry.crt \
 -extensions req_ext \
 -extfile offline-registry-san.cnf

# merge server.crt and cacert.pem
cat /opt/copinekubeca01/certs/offline-registry.crt \
/opt/copinekubeca01/cacert.pem > \
/opt/copinekubeca01/certs/offline-registry-chained.crt

# create subCA
cat /opt/copinekubeca01/certs/kubedev-cluster-subCA.crt /opt/copinekubeca01/cacert.pem > /opt/copinekubeca01/certs/kubedev-cluster-subCA-chained.crt
cp /opt/copinekubeca01/certs/kubedev-cluster-subCA-chained.crt /usr/local/share/ca-certificates/kubedev-cluster-subCA-chained.pem
update-ca-certificates

###############################################################################
# Cluster Initialization
#
# init-cluster.sh
vi /home/adminlocal/kubeadm/init-cluster.sh
#!/usr/bin/env bash
export KUBEADM_CLUSTER_NAME=kubedev
export KUBEADM_OUTPUT_DIR=/opt/kubernetes/_clusters/${KUBEADM_CLUSTER_NAME}
export KUBEADM_TOKEN=$(kubeadm token generate)
export KUBEADM_API_ADVERTISE_IP_1=10.0.3.221
export KUBEADM_API_ADVERTISE_IP_2=10.0.3.222
export KUBEADM_API_ADVERTISE_IP_3=10.0.3.223
export KUBEADM_WORKER_IP_1=10.0.3.224
export KUBEADM_WORKER_IP_2=10.0.3.225
export KUBEADM_WORKER_IP_3=10.0.3.226
export KUBEADM_API_ENDPOINT_INTERNAL=kubedev.cluster.dev.local
export KUBEADM_API_ENDPOINT_EXTERNAL=kubedev.dev.local
export KUBEADM_PKI_HOMEDIR=${KUBEADM_OUTPUT_DIR}/pki
export KUBEADM_KUBECONFIG=${KUBEADM_OUTPUT_DIR}/kubeconfig
export KUBEADM_K8S_VERSION=1.32.1
export KUBEADM_DNS_DOMAIN=cluster.dev.local
export KUBEADM_SERVICE_SUBNET=10.96.0.0/12
export KUBEADM_POD_SUBNET=10.244.0.0/16
mkdir -p ${KUBEADM_OUTPUT_DIR}
mkdir -p ${KUBEADM_PKI_HOMEDIR}
envsubst < kubeadm-init-tmpl.yaml > ${KUBEADM_OUTPUT_DIR}/kubeadm-init-config.yaml
cp /opt/copinekubeca01/certs/kubedev-cluster-subCA-chained.crt ${KUBEADM_PKI_HOMEDIR}/ca.crt
cp /opt/copinekubeca01/private/kubedev-cluster-subCA-key.pem ${KUBEADM_PKI_HOMEDIR}/ca.key
kubeadm init phase certs all --config /opt/kubernetes/_clusters/kubedev/kubeadm-init-config.yaml
export CA_CERT_HASH=$(openssl x509 -pubkey -in ${KUBEADM_PKI_HOMEDIR}/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* /sha256:/')
source /home/adminlocal/kubeadm/generate-admin-client-certs.sh
CLIENT_CERT_B64=$(base64 -w0 < $KUBEADM_PKI_HOMEDIR/kubeadmin.crt)
CLIENT_KEY_B64=$(base64 -w0 < $KUBEADM_PKI_HOMEDIR/kubeadmin.key)
CA_DATA_B64=$(base64 -w0 < $KUBEADM_PKI_HOMEDIR/ca.crt)
envsubst < kubeadm-config-tmpl.yaml > ${KUBEADM_OUTPUT_DIR}/kubeconfig
envsubst < kubeadm-join-config-tmpl.yaml > ${KUBEADM_OUTPUT_DIR}/kubeadm-join-config.yaml
sed -i '/certificatesDir:/d' ${KUBEADM_OUTPUT_DIR}/kubeadm-init-config.yaml
tar -cz --directory=${KUBEADM_PKI_HOMEDIR} . | ssh adminlocal@${KUBEADM_API_ADVERTISE_IP_1} 'mkdir -p /home/adminlocal/kubernetes/pki; tar -xz --directory=/home/adminlocal/kubernetes/pki/'
scp -r ${KUBEADM_OUTPUT_DIR}/kubeadm-init-config.yaml adminlocal@${KUBEADM_API_ADVERTISE_IP_1}:/home/adminlocal/kubernetes/kubeadm-init-config.yaml
scp -r /home/adminlocal/kubeadm/init-kube.sh adminlocal@${KUBEADM_API_ADVERTISE_IP_1}:/home/adminlocal/kubernetes/init-kube.sh
scp -r ${KUBEADM_OUTPUT_DIR}/kubeadm-join-config.yaml adminlocal@${KUBEADM_WORKER_IP_1}:/home/adminlocal/kubeadm-join-config.yaml
scp -r ${KUBEADM_OUTPUT_DIR}/kubeadm-join-config.yaml adminlocal@${KUBEADM_WORKER_IP_2}:/home/adminlocal/kubeadm-join-config.yaml
scp -r ${KUBEADM_OUTPUT_DIR}/kubeadm-join-config.yaml adminlocal@${KUBEADM_WORKER_IP_3}:/home/adminlocal/kubeadm-join-config.yaml


chmod +x /home/adminlocal/kubeadm/init-cluster.sh

-------------------------------------------------------------------------------

# configure cluster initialization
sudo /home/adminlocal/init-cluster.sh

-------------------------------------------------------------------------------

#  from first controller
/home/adminlocal/init-kube.sh


-------------------------------------------------------------------------------

# from kubeadmin
kgall
 * join worker node



calico/node-driver-registrar:v3.29.1



# Install Tigera Calico Network Overlay and Policies (cni/net.d)
kubectl create -f /home/adminlocal/tigera/tigera-operator.yaml

  * update custom-resources.yaml file to match POD subnet
kubectl create -f /home/adminlocal/tigera/custom-resources.yaml

  * update calico.yaml file for cluster environment
sed -i 's/docker.io/offline-registry.dev.local/' /home/adminlocal/tigera/custom-calico.yaml
sed -i 's/:v3.25.0/:v3.29.1/' /home/adminlocal/tigera/custom-calico.yaml
kubectl apply -f /home/adminlocal/tigera/calico.yaml


###############################################################################
# kubeadm-init.tmpl.yaml
#
apiVersion: kubeadm.k8s.io/v1beta4
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: "${KUBEADM_TOKEN}"
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${KUBEADM_API_ADVERTISE_IP_1}
  bindPort: 6443
---
apiServer:
  certSANs:
  - ${KUBEADM_API_ENDPOINT_INTERNAL}
  - ${KUBEADM_API_ENDPOINT_EXTERNAL}
apiVersion: kubeadm.k8s.io/v1beta4
certificatesDir: ${KUBEADM_PKI_HOMEDIR}
clusterName: ${KUBEADM_CLUSTER_NAME}
controlPlaneEndpoint: ${KUBEADM_API_ENDPOINT_INTERNAL}:6443
encryptionAlgorithm: RSA-2048
etcd:
  external:
    endpoints:
      - "https://${KUBEADM_API_ADVERTISE_IP_1}:2379"
      - "https://${KUBEADM_API_ADVERTISE_IP_2}:2379"
      - "https://${KUBEADM_API_ADVERTISE_IP_3}:2379"
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.k8s.io
kind: ClusterConfiguration
kubernetesVersion: ${KUBEADM_K8S_VERSION}
networking:
  dnsDomain: ${KUBEADM_DNS_DOMAIN}
  serviceSubnet: ${KUBEADM_SERVICE_SUBNET}
  podSubnet: ${KUBEADM_POD_SUBNET}


###############################################################################
# kubeadm-join-config.tmpl.yaml
#
apiVersion: kubeadm.k8s.io/v1beta1
kind: JoinConfiguration
nodeRegistration:
kubeletExtraArgs:
enable-controller-attach-detach: "false"
node-labels: "node-type=rook"
discovery:
bootstrapToken:
apiServerEndpoint: ${K8S_API_ENDPOINT_INTERNAL}
 token: ${KUBEADM_TOKEN}
 caCertHashes:
 - ${CA_CERT_HASH}


###############################################################################
# generate CA cert hash : added to init-cluster.sh
#
export CA_CERT_HASH=$(openssl x509 -pubkey -in ${KUBEADM_PKI_HOMEDIR}/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* /sha256:/')


###############################################################################
# generate-admin-client-certs.sh
#
#!/usr/bin/env bash
CERTS_DIR=${1:-$KUBEADM_PKI_HOMEDIR}
CA="${CERTS_DIR}"/ca.crt
CA_KEY="${CERTS_DIR}"/ca.key

if [[ ! -f ${CA} || ! -f ${CA_KEY} ]]; then
echo "Error: CA files ${CA} ${CA_KEY} are missing "
exit 1
fi

CLIENT_SUBJECT=${CLIENT_SUBJECT:-"/O=system:masters/CN=kubernetes-admin"}
CLIENT_CSR=${CERTS_DIR}/kubeadmin.csr
CLIENT_CERT=${CERTS_DIR}/kubeadmin.crt
CLIENT_KEY=${CERTS_DIR}/kubeadmin.key
CLIENT_CERT_EXTENSION=${CERTS_DIR}/cert-extension

# We need faketime for cases when your client time is on UTC+
which faketime >/dev/null 2>&1
if [[ $? == 0 ]]; then
OPENSSL="faketime -f -1d openssl"
else
echo "Warning, faketime is missing, you might have a problem if your server time is less then"
OPENSSL=openssl
fi

echo "OPENSSL = $OPENSSL "
echo "Creating Client KEY $CLIENT_KEY "
$OPENSSL genrsa -out "$CLIENT_KEY" 2048

echo "Creating Client CSR $CLIENT_CSR "
$OPENSSL req -subj "${CLIENT_SUBJECT}" -sha256 -new -key "${CLIENT_KEY}" -out "${CLIENT_CSR}"

echo "--- create ca extfile"
echo "extendedKeyUsage=clientAuth" > "$CLIENT_CERT_EXTENSION"

echo "--- sign certificate ${CLIENT_CERT} "
$OPENSSL x509 -req -days 1096 -sha256 -in "$CLIENT_CSR" -CA "$CA" -CAkey "$CA_KEY" \
-CAcreateserial -out "$CLIENT_CERT" -extfile "$CLIENT_CERT_EXTENSION" -passin pass:"$CA_PASS"


###############################################################################
# kubeadm-config-templ.yaml
#
apiVersion: v1
clusters:
- cluster:
certificate-authority-data: ${CA_DATA_B64}
server: https://${K8S_API_ENDPOINT}:6443
name: ${K8S_CLUSTER_NAME}
contexts:
- context:
cluster: ${K8S_CLUSTER_NAME}
user: ${K8S_CLUSTER_NAME}-admin
namespace: default
name: ${K8S_CLUSTER_NAME}
current-context: ${K8S_CLUSTER_NAME}
kind: Config
preferences: {}
users:
- name: ${K8S_CLUSTER_NAME}-admin
user:
client-certificate-data: ${CLIENT_CERT_B64}
client-key-data: ${CLIENT_KEY_B64}


# Copy certificates to master node
tar -cz --directory=KUBEADM_PKI_HOMEDIR . | ssh 10.0.3.221 -S -p 'S1airarose!895' 'sudo mkdir -p /etc/kubernetes/pki; sudo tar -xz --directory=/etc/kubernetes/pki/'


###############################################################################
# init-kube.sh
#
#!/usr/bin/env bash
sudo mkdir -p /etc/kubernetes/pki
sudo cp -r /home/adminlocal/kubernetes/pki/ /etc/kubernetes/
sudo chown -R root:root /etc/kubernetes/pki/
sudo chmod -R 600 /etc/kubernetes/pki/

# initialize cluster
sudo kubeadm config images pull --image-repository offline-registry.dev.local
sudo kubeadm init --skip-phases certs --config /home/adminlocal/kubernetes/kubeadm-init-config.yaml

# setup kubectl access to cluster
scp /etc/kubernetes/admin.conf adminlocal@kubeadmin.dev.local:$HOME/.kube/config



###############################################################################
# Start/Create Registry Container
#
# run container
nerdctl run -d \
 --restart always \
 --name offline-registry \
 -v "$(pwd)"/certs:/certs \
 -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
 -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
 -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
 -e /data:/var/lib/registry \
 -p 443:443 \
 registry:2


###############################################################################
# Run Pihole on BHN VM
#
systemctl stop systemd-resolved
systemctl disable systemd-resolved

nerdctl run -d \
--name bhnpihole \
-p 53:53/tcp \
-p 53:53/udp \
-p 80:80/tcp \
-e WEBPASSWORD=S1airarose!895 \
-e ServerIP=127.0.0.1
--dns=4.2.2.2 \
--restart=unless-stopped \
--hostname bhnpihole \
-v pihole_app:/etc/pihole/ \
-v pihole_dns_config:/etc/dnsmasq.d \
pihole/pihole:2024.07.0


###############################################################################
# Pull, Re-Tag, and Push Images
#
# Pull Images
for image in `cat /home/adminlocal/offline-images.list`; do nerdctl pull $image; done
for image in `cat /home/adminlocal/offline-images.list`; do nerdctl pull --insecure-registry `echo $image | sed -E 's#^[^/]+/#offline-registry.dev.local:6000/#'`; done

# Re-Tag Images
for image in `cat /home/adminlocal/offline-images.list`; do nerdctl tag $image `echo $image | sed -E 's#^[^/]+/#127.0.0.1:6000/#'`; done

# Push Images
for image in `cat /home/adminlocal/offline-images.list`; do echo $image; nerdctl push `echo $image | sed -E 's#^[^/]+/#127.0.0.1:6000/#'`; done

# Verify Images are Pushed
curl https://offline-registry.dev.local/v2/_catalog


###############################################################################
# Talos API Configuration
#
# Generate default configuration
talosctl gen config kube001 https://kube001.dev.local:6443

# Patching Configurations
Generated machine configuration can also be patched after the fact with talosctl machineconfig patch
talosctl machineconfig patch worker.yaml --patch @workernodes.patch.yaml -o worker1.yaml
talosctl machineconfig patch controlplane.yaml --patch @controlnodes.patch.yaml -o controlplane1.yaml

# Machine configuration on the running Talos node can be patched with talosctl patch:
talosctl patch mc --nodes 172.20.0.2 --patch @patch.yaml

# Apply patched configuration
talosctl apply-config --insecure --nodes 192.168.1.111 --file patchfile.yaml

# Install Cluster
# Kubernetes Bootstrap
talosctl bootstrap --nodes 192.168.0.2 --endpoints 192.168.0.2 --talosconfig=./talosconfig

# After a few moments, you will be able to download your Kubernetes client configuration and get started:
talosctl kubeconfig --nodes 192.168.0.2 --endpoints 192.168.0.2 --talosconfig=./talosconfig

# If you would prefer the configuration to not be merged into your default Kubernetes configuration file, pass in a filename:
talosctl kubeconfig alternative-kubeconfig --nodes 192.168.0.2 --endpoints 192.168.0.2 --talosconfig=./talosconfig
copy alternative-kubeconfig file to $HOME/.kube/config

# govc
# extract govc binary to /usr/local/bin
# note: the "tar" command must run with root permissions
curl -L -o - "https://github.com/vmware/govmomi/releases/latest/download/govc_$(uname -s)_$(uname -m).tar.gz" | tar -C /usr/local/bin -xvzf - govc


###############################################################################
# Install Helm on KubeAdmin
#
sudo apt install apt-transport-https gnupg2 -y

curl https://baltocdn.com/helm/signing.asc | gpg --dearmor \
| sudo tee /etc/apt/trusted.gpg.d/helm.gpg > /dev/null

echo "deb [arch=$(dpkg --print-architecture)] https://baltocdn.com/helm/stable/debian/ all main" | \
sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update
sudo apt install helm


###############################################################################
# Install Helm Charts
#
helm repo add rocketchat https://rocketchat.github.io/helm-charts
helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes/
helm repo add nginx-stable https://helm.nginx.com/stable

$ helm repo add coredns https://coredns.github.io/helm
$ helm --namespace=kube-system install coredns coredns/coredns
