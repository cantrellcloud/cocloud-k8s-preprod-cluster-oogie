# Deploying Helm on Ubuntu 24.04

## Install Helm

sudo apt-get update
sudo apt-get install apt-transport-https --yes
sudo apt-get install ca-certificates curl software-properties-common
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

## Flannel

**Needs manual creation of namespace to avoid helm error**

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

## Calico

```bash
helm repo add projectcalico https://docs.tigera.io/calico/charts
helm repo update
helm pull projectcalico/tigera-operator --version v3.29.2 --untar --untardir .

helm package ../helm/charts/<chart-name> -d ../helm/packages/
helm install calico ../helm/packages/<chart-name>.tzg --namespace tigera-operator --create-namespace

helm upgrade --install calico ${HELM_DIR}/packages/tigera-operator-v3.29.2.tgz --namespace tigera-operator --create-namespace
curl -L https://github.com/projectcalico/calico/releases/download/v3.29.2/calicoctl-linux-amd64 -o calicoctl
chmod +x ./calicoctl
cp ./calicoctl /usr/local/bin/

alias cali=calicoctl
cali ipam show --show-blocks

# from a worker node
sudo calicoctl node status
```

## MetalLB

kubectl edit configmap -n kube-system kube-proxy

```text
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
```

```bash
kubectl create namespace metallb-system
kubectl label --overwrite namespace metallb-system pod-security.kubernetes.io/enforce=privileged
kubectl label --overwrite namespace metallb-system pod-security.kubernetes.io/audit=privileged
kubectl label --overwrite namespace metallb-system pod-security.kubernetes.io/warn=privileged

# by package
helm upgrade --install metallb ../../packages --namespace metallb-system

# by online Internet
helm upgrade --install metallb metallb/metallb --namespace metallb-system
```

## Ingress-Nginx

```bash
helm upgrade --install ingress-nginx ../../packages/ingress-nginx-4.12.0.tgz --namespace ingress-nginx --create-namespace

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace -set "controller.extraArgs.enable-ssl-passthrough=true
```

## Dashboard

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

## Pihole

