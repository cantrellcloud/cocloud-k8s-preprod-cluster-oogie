#!/bin/bash
echo Create a basic auth file auth...
USER=ladmin
PASSWORD=S1airarose!895
echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> /home/kadmin/kubeconf/build/resource-yaml.files/auth
echo
echo ---
echo
echo Create a secret basic-auth...
kubectl -n longhorn-system create secret generic basic-auth --from-file=/home/kadmin/kubeconf/build/resource-yaml.files/auth
echo
echo ---
echo
echo Longhorn basic-auth created.
echo
# End of longhorn-basic-auth.sh