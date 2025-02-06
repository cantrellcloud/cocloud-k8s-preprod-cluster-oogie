#!/usr/bin/env bash
kubectl create -f /home/adminlocal/tigera/tigera-operator.yaml
kubectl create -f /home/adminlocal/tigera/custome-resources.yaml
kubectl apply -f custom-calico.yaml
