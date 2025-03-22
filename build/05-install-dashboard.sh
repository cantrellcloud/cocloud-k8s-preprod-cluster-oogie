#!/usr/bin/env bash
clear
echo
echo Exporting variables...
export KUBE_RESOURCES_DIR=/home/kadmin/cocloud-k8s-preprod-cluster-oogie/build/resource-yaml.files
export HELM_DIR=/home/kadmin/kubeconf/apps/helm
echo
echo ---
echo
echo Installing Kubernetes-Dashboard...
helm upgrade --install kubernetes-dashboard ${HELM_DIR}/packages/kubernetes-dashboard-7.11.1.tgz \
  --namespace kubernetes-dashboard --create-namespace --set nginx.enabled=false --set cert-manager.enabled=false
echo
echo ---
echo
echo Waiting for Kubernetes-Dashboard to be ready...
kubectl wait --for=condition=available --timeout=600s deployment/kubernetes-dashboard-kubernetes-dashboard-metrics-scraper --namespace kubernetes-dashboard
kubectl wait --for=condition=available --timeout=600s deployment/kubernetes-dashboard-kubernetes-dashboard-auth --namespace kubernetes-dashboard
kubectl wait --for=condition=available --timeout=600s deployment/kubernetes-dashboard-kubernetes-dashboard-web --namespace kubernetes-dashboard
kubectl wait --for=condition=available --timeout=600s deployment/kubernetes-dashboard-kubernetes-dashboard-api --namespace kubernetes-dashboard
echo
echo ---
echo
echo Kubernetes-Dashboard installed.
echo
