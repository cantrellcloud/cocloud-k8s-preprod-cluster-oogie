#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/kubeconf/build/resource-yaml.files
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