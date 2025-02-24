#!/usr/bin/env bash
clear
echo
echo BEGIN
echo
echo ---
echo
echo Removing existing cluster data and directories...
echo
rm -rf /opt/kubernetes/_clusters/kubedev
echo
echo ---
echo
echo Sourcing init-cluster.sh...
echo
source ./init-cluster.sh
echo
echo ---
echo
echo END
echo

