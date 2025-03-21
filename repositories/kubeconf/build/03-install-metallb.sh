#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/kubeconf/build/resource-yaml.files
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
kubectl create -f ${KUBE_RESOURCES_DIR}/metallb-ippool-layer2-advertise.yaml
echo
echo ---
echo
echo MetalLB installed.
echo