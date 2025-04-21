# Dockerization and Deployment Guide for Kubernetes DockerHub Image Policy Webhook

This guide provides step-by-step instructions for building, running, and deploying the Kubernetes DockerHub Image Policy Webhook using Docker.

## Prerequisites

- Docker installed on your system
- Docker Compose (optional, for local testing)
- Docker Hub account (for publishing images)
- Access to a Kubernetes cluster (for deployment)

## Building the Docker Image

1. **Clone the repository:**
   ```
   git clone <repository-url>
   cd <repository-directory>
   ```

2. **Build the Docker image:**
   ```
   docker build -t dockerhub-image-policy-webhook:latest .
   ```

3. **Test the Docker image locally:**
   ```
   docker run -p 5000:5000 -e SESSION_SECRET=test_secret dockerhub-image-policy-webhook:latest
   ```

4. **Or use Docker Compose:**
   ```
   docker-compose up
   ```

## Publishing the Image

1. **Tag the image with your Docker Hub username:**
   ```
   docker tag dockerhub-image-policy-webhook:latest <your-dockerhub-username>/dockerhub-image-policy-webhook:latest
   ```

2. **Log in to Docker Hub:**
   ```
   docker login
   ```

3. **Push the image:**
   ```
   docker push <your-dockerhub-username>/dockerhub-image-policy-webhook:latest
   ```

## Deploying to Kubernetes

1. **Update the Kubernetes manifest file:**

   Edit `k8s/webhook-manifests.yaml` and replace the `${YOUR_IMAGE_NAME}` placeholder with your published image name:
   ```
   image: <your-dockerhub-username>/dockerhub-image-policy-webhook:latest
   ```

2. **Set up TLS certificates:**
   Follow the TLS certificate setup instructions in the README.md file.

3. **Update the CA Bundle:**
   Replace the `${CA_BUNDLE}` placeholder in the webhook configuration with the base64-encoded CA certificate:
   ```
   sed -i "s|\${CA_BUNDLE}|$(cat certs/ca.crt | base64 | tr -d '\n')|g" k8s/webhook-manifests.yaml
   ```

4. **Apply the Kubernetes manifests:**
   ```
   kubectl apply -f k8s/webhook-manifests.yaml
   ```

5. **Verify the deployment:**
   ```
   kubectl get pods -n image-policy-system
   ```

## Troubleshooting

1. **Check webhook pod logs:**
   ```
   kubectl logs -n image-policy-system -l app=dockerhub-image-policy-webhook
   ```

2. **Verify service connectivity:**
   ```
   kubectl -n image-policy-system port-forward svc/dockerhub-image-policy-webhook 5000:443
   ```
   Then, in another terminal:
   ```
   curl -k https://localhost:5000/health
   ```

3. **Inspect webhook configuration:**
   ```
   kubectl get validatingwebhookconfiguration dockerhub-image-policy
   ```

## Security Considerations

1. **Environment variables:** Use Kubernetes secrets for production deployments instead of hard-coding the SESSION_SECRET in the manifest.

2. **TLS certificates:** Ensure certificates are properly secured and rotated regularly.

3. **Resource limits:** Adjust the CPU and memory limits in the Kubernetes deployment manifest based on your workload.

## Customization Options

1. **Worker processes:** Adjust the number of Gunicorn workers in the entrypoint.sh file based on your CPU resources.

2. **Logging level:** Set the appropriate logging level for production by modifying the environment variables.

3. **Health checks:** Customize the liveness and readiness probe parameters in the Kubernetes manifest based on your requirements.