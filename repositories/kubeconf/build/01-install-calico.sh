#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/kubeconf/build/resource-yaml.files
export HELM_DIR=/home/kadmin/kubeconf/apps/helm
echo
echo Installing Calico CNI...
helm upgrade --install calico ${HELM_DIR}/packages/tigera-operator-v3.29.2.tgz --namespace tigera-operator --create-namespace
echo
echo ---
echo
echo Waiting for Calico CNI to be ready...
echo
echo 'wait --for=condition=available --timeout=600s deployment/tigera-operator --namespace tigera-operator'
kubectl wait --for=condition=available --timeout=600s deployment/tigera-operator --namespace tigera-operator
echo
echo 'wait --for=condition=available --timeout=600s deployment/calico-typha --namespace calico-system'
kubectl wait --for=condition=available --timeout=600s deployment/calico-typha --namespace calico-system
echo
echo 'wait --for=condition=available --timeout=600s deployment/calico-kube-controllers --namespace calico-system'
kubectl wait --for=condition=available --timeout=600s deployment/calico-kube-controllers --namespace calico-system
echo
echo 'kubectl wait --for=condition=available --timeout=600s deployment/calico-apiserver --namespace calico-apiserver'
kubectl wait --for=condition=available --timeout=600s deployment/calico-apiserver --namespace calico-apiserver
echo
echo ---
echo
#echo Create Calico CNI resources...
#kubectl create -f ${KUBE_RESOURCES_DIR}/calico-resources.yaml
#echo
echo Calico CNI installed.
echo