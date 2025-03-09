#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export HELM_DIR=/home/kadmin/kubeconf/apps/helm
echo
echo Installing Calico CNI...
helm upgrade --install calico ${HELM_DIR}/packages/tigera-operator-v3.29.2.tgz --namespace tigera-operator --create-namespace
echo
echo ---
echo
echo Calico CNI installed.
echo