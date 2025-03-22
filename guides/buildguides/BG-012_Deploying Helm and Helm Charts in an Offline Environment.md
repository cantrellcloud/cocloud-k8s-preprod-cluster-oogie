# Deploying Helm on Ubuntu 24.04

## Install Helm

sudo apt-get update
sudo apt-get install apt-transport-https --yes
sudo apt-get install ca-certificates curl software-properties-common
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

## Install Helm Charts

Install the scripts in the order best suited for your installation.

Special Note: Before installing any of the charts below,
I have already modified each chart for my use and then repackaged. Using the helm -f flag is not needed.
However, helm --set parameters are still valid.

### Flannel

```bash
kubectl create namespace kube-flannel
kubectl label --overwrite namespace kube-flannel pod-security.kubernetes.io/enforce=privileged

helm repo add flannel https://flannel-io.github.io/flannel/
helm repo update
helm pull flannel/flannel --untar --untardir ../helm/charts/

helm package ../helm/charts/<chart-name> -d ../helm/packages/

# by package
helm install flannel ../helm/packages/<chart-name>.tzg --namespace kube-flannel --set podCidr="10.255.0.0/16"

# by online Internet
helm upgrade --install flannel --set podCidr="10.213.0.0/21" --namespace kube-flannel flannel/flannel
```

### Calico

Create bash script: 01-install-calico.sh

```bash
#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/cocloud-k8s-preprod-cluster-oogie/build/resource-yaml.files
export HELM_DIR=/home/kadmin/kubeconf/apps/helm
echo
echo Installing Calico CNI...
helm upgrade --install calico ${HELM_DIR}/packages/tigera-operator-v3.29.2.tgz --namespace tigera-operator --create-namespace
echo
echo ---
echo
echo Waiting for Calico CNI to be ready...
echo
echo 'kubectl wait --for=condition=available --timeout=600s deployment/calico-typha --namespace calico-system'
kubectl wait --for=condition=available --timeout=600s deployment/calico-typha --namespace tigera-system

echo 'kubectl wait --for=condition=available --timeout=600s deployment/calico-apiserver --namespace tigera-system'
kubectl wait --for=condition=available --timeout=600s deployment/calico-apiserver --namespace calico-apiserver

echo 'kubectl wait --for=condition=available --timeout=600s deployment/calico-kube-controllers --namespace tigera-system'
kubectl wait --for=condition=available --timeout=600s deployment/calico-kube-controllers --namespace calico-system

echo 'kubectl wait --for=condition=available --timeout=600s daemonset/calico-node --namespace tigera-system'
kubectl wait --for=condition=available --timeout=600s daemonset/calico-node --namespace calcio-system
echo
echo ---
echo
#echo Create Calico CNI resources...
#kubectl create -f ${KUBE_RESOURCES_DIR}/calico-resources.yaml
#echo
echo Calico CNI installed.
echo
```

### MetalLB

Create bash script: 02-install-metallb.sh

```bash
#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/cocloud-k8s-preprod-cluster-oogie/build/resource-yaml.files
export HELM_DIR=/home/kadmin/kubeconf/apps/helm
echo
echo ---
echo
echo Create namespace and label namespace privileged...
kubectl create namespace metallb-system
kubectl label --overwrite namespace metallb-system pod-security.kubernetes.io/enforce=privileged
kubectl label --overwrite namespace metallb-system pod-security.kubernetes.io/audit=privileged
kubectl label --overwrite namespace metallb-system pod-security.kubernetes.io/warn=privileged
echo
echo ---
echo
echo Installing MetalLB...
helm upgrade --install metallb ${HELM_DIR}/packages/metallb-0.14.9.tgz --namespace metallb-system
echo
echo ---
echo
echo Waiting for MetalLB to be ready...
kubectl wait --for=condition=available --timeout=600s deployment/metallb-controller --namespace metallb-system
kubectl wait --for=condition=available --timeout=600s daemonset/metallb-speaker --namespace metallb-system
echo
echo ---
echo
echo Creating MetalLB Layer2 Advertisment...
kubectl create -f ${KUBE_RESOURCES_DIR}/metallb-layer2-advertise.yaml
echo
echo ---
echo
echo MetalLB installed.
echo
```

### Ingress-Nginx

Create bash script: 03-install-ingress-nginx.sh

```bash
#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/cocloud-k8s-preprod-cluster-oogie/build/resource-yaml.files
export HELM_DIR=/home/kadmin/kubeconf/apps/helm
echo
echo ---
echo
echo Installing Ingress-Nginx...
helm upgrade --install ingress-nginx ${HELM_DIR}/packages/ingress-nginx-4.12.0.tgz \
  --namespace ingress-nginx --create-namespace --set "controller.extraArgs.enable-ssl-passthrough=true"
echo
echo ---
echo
echo Waiting for Ingress-Nginx to be ready...
kubectl wait --for=condition=available --timeout=600s deployment/ingress-nginx-controller --namespace ingress-nginx
echo
echo ---
echo
echo Creating Ingress-Nginx-Controller IP...
kubectl create -f ${KUBE_RESOURCES_DIR}/ingress-nginx-controller-ip.yaml
echo
echo ---
echo
echo Ingress-Nginx installed.
echo
```

### Longhorn Storage

Create bash script: 04-install-longhorn.sh

```bash
#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/cocloud-k8s-preprod-cluster-oogie/build/resource-yaml.files
export HELM_DIR=/home/kadmin/kubeconf/apps/helm
echo
echo ---
echo
echo Installing Longhorn Storage...
helm upgrade --install longhorn ${HELM_DIR}/packages/longhorn-1.8.1.tgz \
  --namespace longhorn-system --create-namespace -f ${HELM_DIR}/charts/longhorn/values.yaml
echo
echo ---
echo
echo Waiting for Longhorn to be ready...
kubectl wait --for=condition=available --timeout=600s deployment/longhorn-manager --namespace longhorn-system
kubectl wait --for=condition=available --timeout=600s deployment/longhorn-driver-deployer --namespace longhorn-system
kubectl wait --for=condition=available --timeout=600s deployment/longhorn-ui --namespace longhorn-system
echo
echo ---
echo
echo Creating longhorn basic-auth...
source ${KUBE_RESOURCES_DIR}/longhorn-basic-auth.sh
echo
echo ---
echo
echo Creating Longhorn Ingress...
kubectl -n longhorn-system create -f ${KUBE_RESOURCES_DIR}/longhorn-ingress.yaml
echo
echo ---
echo
echo Reserving Longhorn IP address...
kubectl -n metallb-system create -f ${KUBE_RESOURCES_DIR}/longhorn-ip.yaml
echo
echo ---
echo
echo Longhorn Storage installed.
echo
```

### Cert-Manager

Create bash script: 05-install-cert-manager.sh

```bash
#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/cocloud-k8s-preprod-cluster-oogie/build/resource-yaml.files
export HELM_DIR=/home/kadmin/kubeconf/apps/helm
echo
echo ---
echo
echo Installing Certificate Manager...
helm upgrade --install cert-manager ${HELM_DIR}/packages/cert-manager-v1.17.1.tgz \
  --namespace cert-manager --create-namespace -f ${HELM_DIR}/charts/cert-manager/values.yaml
echo
echo ---
echo
echo Waiting for Certificate Manager to be ready...
kubectl wait --for=condition=available --timeout=600s deployment/cert-manager --namespace cert-manager
echo
echo ---
echo
echo Certificate Manager installed.
echo
```

### Pihole

Create bash script: 06-install-pihole01.sh

```bash
#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/cocloud-k8s-preprod-cluster-oogie/build/resource-yaml.files
export HELM_DIR=/home/kadmin/kubeconf/apps/helm
echo
echo ---
echo
echo Installing Pihole01...
helm upgrade --install pihole01 ${HELM_DIR}/packages/pihole-2.29.1.tgz -f ${HELM_DIR}/charts/pihole01/values.yaml --namespace pihole-system --create-namespace
echo
echo ---
echo
echo Waiting for Pihole01 to be ready...
kubectl wait --for=condition=available --timeout=600s deployment/pihole01 --namespace pihole-system
echo
echo ---
echo
echo Pihole01 installed.
echo
```

Create bash script: 07-install-pihole02.sh

```bash
#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/cocloud-k8s-preprod-cluster-oogie/build/resource-yaml.files
export HELM_DIR=/home/kadmin/kubeconf/apps/helm
echo
echo ---
echo
echo Installing Pihole02...
helm upgrade --install pihole02 ${HELM_DIR}/packages/pihole-2.29.1.tgz -f ${HELM_DIR}/charts/pihole02/values.yaml --namespace pihole-system
echo
echo ---
echo
echo Waiting for Pihole02 to be ready...
kubectl wait --for=condition=available --timeout=600s deployment/pihole02 --namespace pihole-system
echo
echo ---
echo
echo Pihole02 installed.
echo
```

### Dashboard

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
helm pull kubernetes-dashboard/kubernetes-dashboard --untar --untardir ../helm/charts/

helm package ../helm/charts/<chart-name> -d ../helm/packages/
helm upgrade --install kubernetes-dashboard ../helm/packages/kubernetes-dashboard-7.11.0.tgz --namespace kubernetes-dashboard --create-namespace
```

## Antrea

```bash
helm repo add antrea https://charts.antrea.io
helm repo update
helm pull antrea/antrea --untar --untardir ../helm/charts/

helm package ../helm/charts/<chart-name> -d ../helm/packages/
helm install antrea ../helm/packages/<chart-name>.tgz -namespace kong --create-namespace
helm install flow-aggregator ../helm/packages/<chart-name>.tgz -namespace kong --create-namespace
```

- Upgrade
  - To upgrade the Antrea Helm chart, use the following commands:
  - Upgrading CRDs requires an extra step; see explanation below
kubectl apply -f https://github.com/antrea-io/antrea/releases/download/<TAG>/antrea-crds.yml
helm upgrade antrea antrea/antrea --namespace kube-system --version <TAG>
