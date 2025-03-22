#!/usr/bin/env bash
# label worker nodes
echo Labeling worker nodes...
echo label kubework01...
kubectl label node kubework01 node-role.kubernetes.io/worker=
echo
echo label kubework02...
kubectl label node kubework02 node-role.kubernetes.io/worker=
echo
echo label kubework03...
kubectl label node kubework03 node-role.kubernetes.io/worker=
echo
#echo label kubework04...
#kubectl label node kubework04 node-role.kubernetes.io/worker=
echo
echo Done.
echo
