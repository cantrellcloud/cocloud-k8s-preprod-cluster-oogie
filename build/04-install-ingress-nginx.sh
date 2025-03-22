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
#echo
#echo Creating Ingress-Nginx-Controller IP...
#kubectl create -f ${KUBE_RESOURCES_DIR}/ingress-nginx-controller-ip.yaml
#echo
#echo ---
echo
echo Ingress-Nginx installed.
echo