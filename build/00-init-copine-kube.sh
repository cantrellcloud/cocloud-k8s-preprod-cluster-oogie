#!/usr/bin/env bash
clear
echo
echo
echo Exporting variables
export KUBECONF_CLUSTER_NAME=copine-kube
export KUBECONF_OUTPUT_DIR=/opt/kubeclusters/${KUBECONF_CLUSTER_NAME}
export KUBECONF_BUILD_DIR=/home/kadmin/cocloud-k8s-preprod-cluster-oogie/build
export KUBECONF_REMOTE_DIR=/home/kadmin/kubernetes
export KUBECONF_PKI_ALGORITHM=RSA-2048
export KUBECONF_TOKEN=$(kubeadm token generate)
export KUBECONF_API_IP_1=10.0.69.51
export KUBECONF_API_NODE_NAME_1=kubectrl01
export KUBECONF_API_IP_2=10.0.69.52
export KUBECONF_API_NODE_NAME_2=kubectrl02
export KUBECONF_API_IP_3=10.0.69.53
export KUBECONF_API_NODE_NAME_3=kubectrl03
export KUBECONF_WORKER_IP_1=10.0.69.54
export KUBECONF_WORKER_NAME_1=kubework01
export KUBECONF_WORKER_IP_2=10.0.69.55
export KUBECONF_WORKER_NAME_2=kubework02
export KUBECONF_WORKER_IP_3=10.0.69.56
export KUBECONF_WORKER_NAME_3=kubework03
#export KUBECONF_WORKER_IP_4=10.0.69.57
#export KUBECONF_WORKER_NAME_4=kubework04
export KUBECONF_API_ENDPOINT_INTERNAL=kube.k8.cantrellcloud.net
export KUBECONF_API_ENDPOINT_EXTERNAL=copine-kube.cantrellcloud.net
export KUBECONF_PKI_HOMEDIR=${KUBECONF_OUTPUT_DIR}/pki
export KUBECONF_KUBECONFIG=${KUBECONF_OUTPUT_DIR}/config
export KUBECONF_K8S_VERSION=1.32.3
export KUBECONF_K8S_IMAGE_REPO=kuberegistry.k8.cantrellcloud.net
export KUBECONF_DNS_DOMAIN=k8.cantrellcloud.net
export KUBECONF_SERVICE_SUBNET=10.69.0.0/16
export KUBECONF_POD_SUBNET=10.169.0.0/16
echo
echo ---
echo
echo Removing prior cluster data and directories...${KUBECONF_OUTPUT_DIR}
rm -rf ${KUBECONF_OUTPUT_DIR}
echo
echo ---
echo
echo Creating directories ...${KUBECONF_OUTPUT_DIR}...${KUBECONF_PKI_HOMEDIR}
mkdir -p ${KUBECONF_OUTPUT_DIR}
mkdir -p ${KUBECONF_PKI_HOMEDIR}
echo
echo ---
echo
echo Create cluster initialization file from template...${KUBECONF_OUTPUT_DIR}/kubeadm-init-config.yaml
envsubst < ${KUBECONF_BUILD_DIR}/kubeadm-init-config-tmpl-v1beta4.yaml > ${KUBECONF_OUTPUT_DIR}/kubeadm-init-config.yaml
echo
echo ---
echo
echo Copy cluster CA files to cluster PKI directory...${KUBECONF_PKI_HOMEDIR}/ca.crt...${KUBECONF_PKI_HOMEDIR}/ca.key
cp ${KUBECONF_BUILD_DIR}/certs/ca.crt ${KUBECONF_PKI_HOMEDIR}/ca.crt
cp ${KUBECONF_BUILD_DIR}/certs/ca.key ${KUBECONF_PKI_HOMEDIR}/ca.key
echo
echo ---
echo
echo kubeadm init phas certs all... --config ${KUBECONF_OUTPUT_DIR} -v=5
kubeadm init phase certs all --config ${KUBECONF_OUTPUT_DIR}/kubeadm-init-config.yaml -v=5
echo
echo ---
echo
echo Export CA cert hash for admin client certificates...
export CA_CERT_HASH=$(openssl x509 -pubkey -in ${KUBECONF_PKI_HOMEDIR}/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* /sha256:/')
echo
echo ---
echo
echo Call script to generate admin client certificates...
source ${KUBECONF_BUILD_DIR}/generate-admin-client-certs.sh
echo
echo ---
echo
echo Set client certificate variables...
CLIENT_CERT_B64=$(base64 -w0 < $KUBECONF_PKI_HOMEDIR/kubeadmin.crt)
CLIENT_KEY_B64=$(base64 -w0 < $KUBECONF_PKI_HOMEDIR/kubeadmin.key)
CA_DATA_B64=$(base64 -w0 < $KUBECONF_PKI_HOMEDIR/ca.crt)
echo
echo ---
echo
echo Create config and join files from templates...
envsubst < ${KUBECONF_BUILD_DIR}/kubeadm-client-config-tmpl.yaml > ${KUBECONF_OUTPUT_DIR}/kubeconfig
envsubst < ${KUBECONF_BUILD_DIR}/kubeadm-join-config-tmpl-v1beta4.yaml > ${KUBECONF_OUTPUT_DIR}/kubeadm-join-config.yaml
echo
echo ---
echo
echo Copy files to remote nodes...
echo Running... sed -i '/certificatesDir:/d' ${KUBECONF_OUTPUT_DIR}/kubeadm-init-config.yaml
sed -i '/certificatesDir:/d' ${KUBECONF_OUTPUT_DIR}/kubeadm-init-config.yaml
echo
echo
echo Tar and copy...
echo 
tar -cz --directory=${KUBECONF_PKI_HOMEDIR} . | ssh kadmin@${KUBECONF_API_IP_1} 'mkdir -p '${KUBECONF_REMOTE_DIR}'/pki; tar -xz --directory='${KUBECONF_REMOTE_DIR}'/pki/'
echo
echo ---
echo
echo Copy init-kube to... ${KUBECONF_API_IP_1}
scp ${KUBECONF_BUILD_DIR}/init-kube.sh kadmin@${KUBECONF_API_IP_1}:${KUBECONF_REMOTE_DIR}/init-kube.sh
echo
echo ---
echo
echo Copy kubeadm-init-config to... ${KUBECONF_API_IP_1}
scp ${KUBECONF_OUTPUT_DIR}/kubeadm-init-config.yaml kadmin@${KUBECONF_API_IP_1}:${KUBECONF_REMOTE_DIR}/kubeadm-init-config.yaml
echo
echo ---
echo
echo Create remote directories on worker nodes... ${KUBECONF_WORKER_IP_1}, ${KUBECONF_WORKER_IP_2}, ${KUBECONF_WORKER_IP_3} #, ${KUBECONF_WORKER_IP_4} 
ssh kadmin@${KUBECONF_WORKER_IP_1} 'mkdir -p '${KUBECONF_REMOTE_DIR}
ssh kadmin@${KUBECONF_WORKER_IP_2} 'mkdir -p '${KUBECONF_REMOTE_DIR}
ssh kadmin@${KUBECONF_WORKER_IP_3} 'mkdir -p '${KUBECONF_REMOTE_DIR}
#ssh kadmin@${KUBECONF_WORKER_IP_4} 'mkdir -p '${KUBECONF_REMOTE_DIR}
echo
echo ---
echo
echo Copy kubeadm-join-config to... ${KUBECONF_WORKER_IP_1}, ${KUBECONF_WORKER_IP_2}, ${KUBECONF_WORKER_IP_3} #, ${KUBECONF_WORKER_IP_4}
scp ${KUBECONF_OUTPUT_DIR}/kubeadm-join-config.yaml kadmin@${KUBECONF_WORKER_IP_1}:${KUBECONF_REMOTE_DIR}/kubeadm-join-config.yaml
scp ${KUBECONF_OUTPUT_DIR}/kubeadm-join-config.yaml kadmin@${KUBECONF_WORKER_IP_2}:${KUBECONF_REMOTE_DIR}/kubeadm-join-config.yaml
scp ${KUBECONF_OUTPUT_DIR}/kubeadm-join-config.yaml kadmin@${KUBECONF_WORKER_IP_3}:${KUBECONF_REMOTE_DIR}/kubeadm-join-config.yaml
#scp ${KUBECONF_OUTPUT_DIR}/kubeadm-join-config.yaml kadmin@${KUBECONF_WORKER_IP_4}:${KUBECONF_REMOTE_DIR}/kubeadm-join-config.yaml
echo
echo ---
echo
echo Copy join-cluster... ${KUBECONF_WORKER_IP_1}, ${KUBECONF_WORKER_IP_2}, ${KUBECONF_WORKER_IP_3} #, ${KUBECONF_WORKER_IP_4}
scp ${KUBECONF_BUILD_DIR}/join-cluster.sh kadmin@${KUBECONF_WORKER_IP_1}:${KUBECONF_REMOTE_DIR}/join-cluster.sh
scp ${KUBECONF_BUILD_DIR}/join-cluster.sh kadmin@${KUBECONF_WORKER_IP_2}:${KUBECONF_REMOTE_DIR}/join-cluster.sh
scp ${KUBECONF_BUILD_DIR}/join-cluster.sh kadmin@${KUBECONF_WORKER_IP_3}:${KUBECONF_REMOTE_DIR}/join-cluster.sh
#scp ${KUBECONF_BUILD_DIR}/join-cluster.sh kadmin@${KUBECONF_WORKER_IP_4}:${KUBECONF_REMOTE_DIR}/join-cluster.sh
echo
echo ---
echo
echo Initialize cluster... ssh -t kadmin@${KUBECONF_API_IP_1} sudo ${KUBECONF_REMOTE_DIR}/init-kube.sh
ssh -t kadmin@${KUBECONF_API_IP_1} sudo ${KUBECONF_REMOTE_DIR}/init-kube.sh
echo
echo ---
echo
echo Join worker nodes... ${KUBECONF_WORKER_IP_1}, ${KUBECONF_WORKER_IP_2}, ${KUBECONF_WORKER_IP_3} #, ${KUBECONF_WORKER_IP_4}
ssh -t kadmin@${KUBECONF_WORKER_IP_1} sudo ${KUBECONF_REMOTE_DIR}/join-cluster.sh
ssh -t kadmin@${KUBECONF_WORKER_IP_2} sudo ${KUBECONF_REMOTE_DIR}/join-cluster.sh
ssh -t kadmin@${KUBECONF_WORKER_IP_3} sudo ${KUBECONF_REMOTE_DIR}/join-cluster.sh
#ssh -t kadmin@${KUBECONF_WORKER_IP_4} sudo ${KUBECONF_REMOTE_DIR}/join-cluster.sh
echo
echo ---
echo
#echo Label nodes... 
${KUBECONF_BUILD_DIR}/label-worker-nodes.sh
echo
echo ---
echo
echo DONE Happy Kubernetting!
echo
echo
