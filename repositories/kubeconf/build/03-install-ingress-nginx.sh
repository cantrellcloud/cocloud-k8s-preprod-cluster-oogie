#!/usr/bin/env bash
clear
echo
echo Exporting variables...
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
echo Ingress-Nginx installed.
echo