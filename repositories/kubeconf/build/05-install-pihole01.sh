#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/kubeconf/build/resource-yaml.files
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
