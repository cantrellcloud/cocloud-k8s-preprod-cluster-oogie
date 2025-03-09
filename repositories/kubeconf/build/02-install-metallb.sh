#!/usr/bin/env bash
clear
echo
echo Exporting variables...
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
#kubectl create -f ${HELM_DIR}/charts/metallb/ipaddresspool-cr.yaml
echo
echo ---
echo
echo MetalLB installed.
echo