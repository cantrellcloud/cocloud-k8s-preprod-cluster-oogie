#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/kubeconf/build/resource-yaml.files
export HELM_DIR=/home/kadmin/kubeconf/apps/helm
echo
echo ---
echo
echo Installing Pihole02...
helm upgrade --install pihole02 ${HELM_DIR}/packages/pihole02/pihole-2.29.1.tgz -f ${HELM_DIR}/charts/pihole02/values.yaml --namespace pihole-system
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
