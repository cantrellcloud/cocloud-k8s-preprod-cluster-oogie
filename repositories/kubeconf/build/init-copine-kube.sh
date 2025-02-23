#!/usr/bin/env bash
clear
echo
echo
echo Exporting variables
export KUBECONF_CLUSTER_NAME=copine-kube
export KUBECONF_OUTPUT_DIR=/opt/kubes/${KUBECONF_CLUSTER_NAME}
export KUBECONF_BUILD_DIR=/home/kadmin/kubeconf/build
export KUBECONF_TOKEN=$(kubeadm token generate)
export KUBECONF_API_ADVERTISE_IP_1=10.0.69.51
export KUBECONF_API_ADVERTISE_IP_2=10.0.69.52
export KUBECONF_API_ADVERTISE_IP_3=10.0.69.53
export KUBECONF_WORKER_IP_1=10.0.69.54
export KUBECONF_WORKER_IP_2=10.0.69.55
export KUBECONF_WORKER_IP_3=10.0.69.56
export KUBECONF_API_ENDPOINT_INTERNAL=kube.k8.cantrellcloud.net
export KUBECONF_API_ENDPOINT_EXTERNAL=copine-kube.cantrellcloud.net
export KUBECONF_PKI_HOMEDIR=${KUBECONF_OUTPUT_DIR}/pki
export KUBECONF_KUBECONFIG=${KUBECONF_OUTPUT_DIR}/config
export KUBECONF_K8S_VERSION=1.32.2
export KUBECONF_DNS_DOMAIN=k8.cantrellcloud.net
export KUBECONF_SERVICE_SUBNET=10.69.0.0/12
export KUBECONF_POD_SUBNET=10.213.0.0/16
echo -----------------------------
echo Removing prior cluster directories
rm -rf ${KUBECONF_OUTPUT_DIR}
echo -----------------------------
echo Create cluster directories
mkdir -p ${KUBECONF_OUTPUT_DIR}
mkdir -p ${KUBECONF_PKI_HOMEDIR}
echo -----------------------------
echo Create config file from template
envsubst < kubeadm-init-tmpl.yaml > ${KUBECONF_OUTPUT_DIR}/kubeadm-init-config.yaml
echo -----------------------------
echo Copy certificate files to PKI HomeDir
cp ${KUBECONF_BUILD_DIR}/certs/copine-kube-chain.crt ${KUBECONF_PKI_HOMEDIR}/ca.crt
cp ${KUBECONF_BUILD_DIR}/certs/copine-kube-key.pem ${KUBECONF_PKI_HOMEDIR}/ca.key
echo -----------------------------
echo
echo kubeadm reset -f
kubeadm reset -f
echo kubeadm init phase certs
kubeadm init phase certs all --config ${KUBECONF_OUTPUT_DIR}/kubeadm-init-config.yaml -v=9
echo -----------------------------
echo Export CA cert hash
export CA_CERT_HASH=$(openssl x509 -pubkey -in ${KUBECONF_PKI_HOMEDIR}/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* /sha256:/')
echo -----------------------------
echo Call generate admin client certs
source ${KUBECONF_BUILD_DIR}/generate-admin-client-certs.sh
echo -----------------------------
echo Set client certificate variables
CLIENT_CERT_B64=$(base64 -w0 < $KUBECONF_PKI_HOMEDIR/kubeadmin.crt)
CLIENT_KEY_B64=$(base64 -w0 < $KUBECONF_PKI_HOMEDIR/kubeadmin.key)
CA_DATA_B64=$(base64 -w0 < $KUBECONF_PKI_HOMEDIR/ca.crt)
echo -----------------------------
echo Create config files from templates
envsubst < kubeadm-config-tmpl.yaml > ${KUBECONF_OUTPUT_DIR}/kubeconfig
envsubst < kubeadm-join-config-tmpl.yaml > ${KUBECONF_OUTPUT_DIR}/kubeadm-join-config.yaml
echo -----------------------------
echo Copy files to remote nodes
sed -i '/certificatesDir:/d' ${KUBECONF_OUTPUT_DIR}/kubeadm-init-config.yaml 
tar -cz --directory=${KUBECONF_PKI_HOMEDIR} . | ssh kadmin@${KUBECONF_API_ADVERTISE_IP_1} 'mkdir -p /home/kadmin/kubernetes/pki; tar -xz --directory=/home/kadmin/kubernetes/pki/'
scp ${KUBECONF_BUILD_DIR}/init-kube.sh kadmin@${KUBECONF_API_ADVERTISE_IP_1}:/home/kadmin/kubernetes/init-kube.sh
scp ${KUBECONF_OUTPUT_DIR}/kubeadm-init-config.yaml kadmin@${KUBECONF_API_ADVERTISE_IP_1}:/home/kadmin/kubernetes/kubeadm-init-config.yaml
scp ${KUBECONF_OUTPUT_DIR}/kubeadm-join-config.yaml kadmin@${KUBECONF_WORKER_IP_1}:/home/kadmin/kubeadm-join-config.yaml
scp ${KUBECONF_OUTPUT_DIR}/kubeadm-join-config.yaml kadmin@${KUBECONF_WORKER_IP_2}:/home/kadmin/kubeadm-join-config.yaml
scp ${KUBECONF_OUTPUT_DIR}/kubeadm-join-config.yaml kadmin@${KUBECONF_WORKER_IP_3}:/home/kadmin/kubeadm-join-config.yaml
echo -----------------------------
echo DONE
echo
