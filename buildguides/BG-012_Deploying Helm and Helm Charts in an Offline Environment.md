# Deploying Helm on Ubuntu 24.04

## Install Helm

1. **Update your package list**:
   sudo apt-get update

2. **Install necessary packages**:
   sudo apt-get install apt-transport-https --yes
   sudo apt-get install ca-certificates curl software-properties-common

3. **Add the Helm GPG key**:
   curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

4. **Add the Helm repository**:
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

5. **Update your package list again**:
   sudo apt-get update

6. **Install Helm**:
   sudo apt-get install helm

7. **Verify the installation**:
   helm version

## Steps to install Calico CNI v3.29 on your Kubernetes v1.32 cluster using Helm

1. **Add the Calico Helm repository**:
   helm repo add projectcalico https://docs.tigera.io/calico/charts
   helm repo update

2. **Create the `tigera-operator` namespace**:
   kubectl create namespace tigera-operator

3. **Install the Tigera operator and custom resource definitions using the Helm chart**:
   helm install calico projectcalico/tigera-operator --version v3.29.2 --namespace tigera-operator

4. **Verify that all the pods are running**:
   watch kubectl get pods -n calico-system
   Wait until each pod has the status `Running`.

## To extract the images needed for each Helm chart for use in an offline environment, you can follow these steps

1. **Render the Helm chart to YAML**:
   helm template <chart-name> --namespace <namespace> > rendered.yaml

2. **Extract the image references**:
   You can use `yq` or `grep` to extract the image references from the rendered YAML file. Here are two methods:

   - Using `yq`:
     yq e '..|.image? | select(.)' rendered.yaml | sort -u

   - Using `grep` and `sed`:
     grep 'image:' rendered.yaml | sed -e 's/[ ]*image:[ ]*//' -e 's/\"//g' | sort -u

3. **Pull the images**:
   On a machine with internet access, pull the images:
   docker pull <image-name>

4. **Save the images to tar files**:
   docker save -o <image-name>.tar <image-name>

5. **Transfer the tar files to the offline environment**:
   Use a USB drive or any other method to transfer the tar files to the offline environment.

6. **Load the images into the offline Docker registry**:
   docker load -i <image-name>.tar