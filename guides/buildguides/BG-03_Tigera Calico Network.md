# Title Here

## SubTitle Here



### Detailed Deployment Guide for Tigera Calico VXLAN Network Overlay on Kubernetes On-Premises

#### 1. **Introduction**

This guide provides detailed steps for deploying Tigera Calico VXLAN network overlay on Kubernetes clusters in an on-premises environment without access to online repositories, cloud services, or the Internet.

#### 2. **Prerequisites**

- **Kubernetes Cluster**: Ensure you have a Kubernetes cluster set up in your on-premises environment.
- **Local Docker Registry**: Set up a local Docker registry to store Calico images.
- **Calico Images**: Download the necessary Calico images and store them in your local registry.
- **Network Configuration**: Ensure your network is configured to allow VXLAN traffic.

#### 3. **Setting Up Local Docker Registry**

1. **Install Docker**: Ensure Docker is installed on your local machine.
2. **Run Local Registry**: Start a local Docker registry.

   ```bash
   docker run -d -p 5000:5000 --name registry registry:2
   ```

#### 4. **Downloading Calico Images**

1. **Download Images**: Download the necessary Calico images from an online source and transfer them to your local environment.
2. **Load Images**: Load the images into your local Docker registry.

   ```bash
   docker load -i calico-node.tar
   docker load -i calico-cni.tar
   docker load -i calico-kube-controllers.tar
   docker load -i calico-typha.tar
   ```

#### 5. **Pushing Images to Local Registry**

1. **Tag Images**: Tag the images for your local registry.

   ```bash
   docker tag calico-node:latest localhost:5000/calico-node:latest
   docker tag calico-cni:latest localhost:5000/calico-cni:latest
   docker tag calico-kube-controllers:latest localhost:5000/calico-kube-controllers:latest
   docker tag calico-typha:latest localhost:5000/calico-typha:latest
   ```

2. **Push Images**: Push the images to your local registry.

   ```bash
   docker push localhost:5000/calico-node:latest
   docker push localhost:5000/calico-cni:latest
   docker push localhost:5000/calico-kube-controllers:latest
   docker push localhost:5000/calico-typha:latest
   ```

#### 6. **Configuring Calico VXLAN**

1. **Download Calico Manifests**: Download the Calico manifests and modify them to use your local registry.

   ```bash
   curl -O https://docs.projectcalico.org/v3.29/manifests/calico.yaml
   ```

2. **Edit Manifests**: Update the image paths in the `calico.yaml` file to point to your local registry.

   ```yaml
   - name: calico-node
     image: localhost:5000/calico-node:latest
   - name: calico-cni
     image: localhost:5000/calico-cni:latest
   - name: calico-kube-controllers
     image: localhost:5000/calico-kube-controllers:latest
   - name: calico-typha
     image: localhost:5000/calico-typha:latest
   ```

#### 7. **Deploying Calico**

1. **Apply Manifests**: Apply the modified Calico manifests to your Kubernetes cluster.

   ```bash
   kubectl apply -f calico.yaml
   ```

2. **Verify Deployment**: Verify that Calico pods are running.

   ```bash
   kubectl get pods -n calico-system
   ```

#### 8. **Configuring VXLAN**

1. **Configure IP Pools**: Configure Calico IP pools to use VXLAN.

   ```yaml
   apiVersion: projectcalico.org/v3
   kind: IPPool
   metadata:
     name: default-ipv4-ippool
   spec:
     cidr: 192.168.0.0/16
     encapsulation: VXLAN
     natOutgoing: true
     nodeSelector: all()
   ```

2. **Apply IP Pool Configuration**: Apply the IP pool configuration.

   ```bash
   kubectl apply -f ippool.yaml
   ```

#### 9. **Testing and Validation**

1. **Deploy Test Pods**: Deploy test pods to verify network connectivity.

   ```bash
   kubectl run test-pod --image=busybox --command -- sleep 3600
   ```

2. **Verify Connectivity**: Verify that the test pods can communicate with each other across nodes.

   ```bash
   kubectl exec -it test-pod -- ping <other-pod-ip>
   ```

#### 10. **Conclusion**

This guide provides a detailed step-by-step process for deploying Tigera Calico VXLAN network overlay on Kubernetes in an on-premises environment without access to online repositories, cloud services, or the Internet. By following these steps, you can ensure a robust and scalable network setup for your Kubernetes clusters.
