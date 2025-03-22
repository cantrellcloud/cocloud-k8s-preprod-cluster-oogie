# Title Here

## SubTitle Here

### MongoDB Setup

#### 1. **Persistent Volume Claim (PVC)**

A Persistent Volume Claim is used to request storage resources for MongoDB. This ensures that MongoDB data is stored persistently and is not lost when pods are restarted or rescheduled.

**PVC Manifest:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

- **accessModes**: Specifies that the volume can be mounted as read-write by a single node.
- **resources.requests.storage**: Requests 10Gi of storage for MongoDB data.

#### 2. **MongoDB Deployment**

The MongoDB deployment defines how MongoDB pods are created and managed. It includes the container image, ports, and volume mounts.

**Deployment Manifest:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
      - name: mongo
        image: localhost:5000/mongo:latest
        ports:
        - containerPort: 27017
        volumeMounts:
        - name: mongo-persistent-storage
          mountPath: /data/db
      volumes:
      - name: mongo-persistent-storage
        persistentVolumeClaim:
          claimName: mongo-pvc
```

- **replicas**: Specifies the number of MongoDB pod replicas (set to 1 for a single instance).
- **image**: Points to the MongoDB image stored in the local Docker registry.
- **ports**: Exposes port 27017 for MongoDB.
- **volumeMounts**: Mounts the persistent storage at `/data/db` inside the MongoDB container.
- **volumes**: References the Persistent Volume Claim created earlier.

#### 3. **MongoDB Service**

The MongoDB service exposes the MongoDB deployment within the Kubernetes cluster, allowing other pods (like Rocket.Chat) to connect to it.

**Service Manifest:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongo
spec:
  selector:
    app: mongo
  ports:
    - protocol: TCP
      port: 27017
      targetPort: 27017
```

- **selector**: Matches the MongoDB pods using the label `app: mongo`.
- **ports**: Exposes port 27017 for MongoDB connections.

### Steps to Deploy MongoDB

1. **Apply the Persistent Volume Claim:**

   ```bash
   kubectl apply -f mongo-pvc.yaml
   ```

2. **Apply the MongoDB Deployment:**

   ```bash
   kubectl apply -f mongo-deployment.yaml
   ```

3. **Apply the MongoDB Service:**

   ```bash
   kubectl apply -f mongo-service.yaml
   ```

4. **Verify Deployment:**
   Ensure that the MongoDB pod is running and the service is correctly set up.

   ```bash
   kubectl get pods
   kubectl get svc
   ```

### Connecting Rocket.Chat to MongoDB

In the Rocket.Chat deployment manifest, set the `MONGO_URL` and `MONGO_OPLOG_URL` environment variables to point to the MongoDB service:

```yaml
env:
- name: MONGO_URL
  value: "mongodb://mongo:27017/rocketchat"
- name: MONGO_OPLOG_URL
  value: "mongodb://mongo:27017/local"
```

This setup ensures that Rocket.Chat can connect to MongoDB for storing and retrieving data.
