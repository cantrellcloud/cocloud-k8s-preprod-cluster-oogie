#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/kubeconf/build/resource-yaml.files
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
#echo Creating Longhorn Ingress...
#kubectl -n longhorn-system create -f ${KUBE_RESOURCES_DIR}/longhorn-ingress.yaml
#echo
#echo ---
#echo
#echo Reserving Longhorn IP address...
#kubectl -n metallb-system create -f ${KUBE_RESOURCES_DIR}/longhorn-ip.yaml
#echo
echo ---
echo
echo Longhorn Storage installed.
echo