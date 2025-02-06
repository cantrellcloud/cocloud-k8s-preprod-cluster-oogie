#!/usr/bin/env bash
export KUBEADM_CLUSTER_NAME=kubedev
export KUBEADM_OUTPUT_DIR=/opt/kubernetes/_clusters/${KUBEADM_CLUSTER_NAME}
export KUBEADM_TOKEN=$(kubeadm token generate)
export KUBEADM_API_ADVERTISE_IP_1=10.0.3.221
export KUBEADM_API_ADVERTISE_IP_2=10.0.3.222
export KUBEADM_API_ADVERTISE_IP_3=10.0.3.223
export KUBEADM_API_ENDPOINT_INTERNAL=kubedev.dev.local
export KUBEADM_API_ENDPOINT_EXTERNAL=kubedev.dev.local
export KUBEADM_PKI_HOMEDIR=${KUBEADM_OUTPUT_DIR}/pki
export KUBEADM_KUBECONFIG=${KUBEADM_OUTPUT_DIR}/kubeconfig
export KUBEADM_K8S_VERSION=1.32.1
export KUBEADM_DNS_DOMAIN=kubedev.dev.local
export KUBEADM_SERVICE_SUBNET=10.96.0.0/12
export KUBEADM_POD_SUBNET=10.244.0.0/16
mkdir -p ${KUBEADM_OUTPUT_DIR}
mkdir -p ${KUBEADM_PKI_HOMEDIR}
envsubst < kubeadm-init-tmpl.yaml > ${KUBEADM_OUTPUT_DIR}/kubeadm-init-config.yaml
cp /opt/ca/certs/kubedev-cluster-subCA.crt ${KUBEADM_PKI_HOMEDIR}/ca.crt
cp /opt/ca/private/kubedev-cluster-subCA-key.pem ${KUBEADM_PKI_HOMEDIR}/ca.key
kubeadm init phase certs all --config /opt/kubernetes/_clusters/kubedev/kubeadm-init-config.yaml
export CA_CERT_HASH=$(openssl x509 -pubkey -in ${KUBEADM_PKI_HOMEDIR}/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* /sha256:/')
source /home/adminlocal/kubeadm/generate-admin-client-certs.sh
CLIENT_CERT_B64=$(base64 -w0 < $KUBEADM_PKI_HOMEDIR/kubeadmin.crt)
CLIENT_KEY_B64=$(base64 -w0 < $KUBEADM_PKI_HOMEDIR/kubeadmin.key)
CA_DATA_B64=$(base64 -w0 < $KUBEADM_PKI_HOMEDIR/ca.crt)
envsubst < kubeadm-config-tmpl.yaml > ${KUBEADM_OUTPUT_DIR}/kubeconfig
sed -i '/certificatesDir:/d' ${KUBEADM_OUTPUT_DIR}/kubeadm-init-config.yaml 
tar -cz --directory=${KUBEADM_PKI_HOMEDIR} . | ssh adminlocal@${KUBEADM_API_ADVERTISE_IP_1} 'mkdir -p /home/adminlocal/kubernetes/pki; tar -xz --directory=/home/adminlocal/kubernetes/pki/'
scp -r ${KUBEADM_OUTPUT_DIR}/kubeadm-init-config.yaml adminlocal@${KUBEADM_API_ADVERTISE_IP_1}:/home/adminlocal/kubernetes/kubeadm-init-config.yaml
