# DockerHub Image Policy Webhook Deployment Guide

This document outlines the deployment process for the DockerHub Image Policy Webhook, a Kubernetes admission controller that validates container images to ensure they come only from DockerHub.

## Prerequisites

- Kubernetes cluster with version 1.16+ 
- `kubectl` command-line tool
- Access to the Kubernetes control plane nodes
- OpenSSL for certificate generation
- Docker or another container runtime for building the webhook image

## Deployment Steps

### 1. Build and Push the Docker Image

Build the webhook Docker image and push it to a registry accessible by your Kubernetes cluster:

```bash
# Build the image
docker build -t techiescamp/kubeimageguard:latest .

# Push to DockerHub
docker push techiescamp/kubeimageguard:latest
```

### 2. Generate Certificates

The webhook requires TLS certificates for secure communication with the Kubernetes API server:

```bash
./scripts/generate-certificates.sh
```

This script:
- Generates a CA key and certificate
- Creates webhook server certificates
- Generates client certificates for the API server
- Creates a base64-encoded CA bundle for the webhook configuration

### 3. Deploy the Webhook Components

Install the webhook components into your Kubernetes cluster:

```bash
# Use the official image from DockerHub (default)
./scripts/install-webhook.sh

# Or specify a different image if needed
./scripts/install-webhook.sh your-registry/your-image:tag
```

This script:
- Creates the `image-policy-system` namespace
- Creates the TLS secret with the webhook certificates
- Deploys the webhook service and deployment
- Applies the ValidatingWebhookConfiguration

### 4. Update Kubernetes API Server Configuration

To enable the ImagePolicyWebhook admission controller, you need to update the Kubernetes API server configuration on each control plane node:

1. Copy the necessary files to each control plane node:
   ```bash
   # On the control plane node
   sudo mkdir -p /etc/kubernetes/pki
   
   # Copy files from your deployment machine to the control plane node
   sudo cp certs/ca.crt /etc/kubernetes/pki/admission-webhook-ca.crt
   sudo cp certs/apiserver-client.crt /etc/kubernetes/pki/apiserver-client.crt
   sudo cp certs/apiserver-client.key /etc/kubernetes/pki/apiserver-client.key
   sudo cp k8s/image-policy-config.yaml /etc/kubernetes/image-policy-config.yaml
   sudo cp k8s/webhook-kubeconfig.yaml /etc/kubernetes/webhook-kubeconfig.yaml
   ```

2. Update the kube-apiserver configuration:
   ```bash
   sudo ./scripts/update-apiserver-config.sh
   ```

3. Verify the API server restarts properly:
   ```bash
   kubectl get pods -n kube-system | grep kube-apiserver
   ```

### 5. Test the Webhook

Apply the test deployment to verify the webhook is working properly:

```bash
kubectl apply -f k8s/test-deployment.yaml
```

This will attempt to create two deployments:
- `nginx-test`: Uses a DockerHub image (`nginx:latest`) - Should be ALLOWED
- `nginx-test-gcr`: Uses a GCR image (`gcr.io/google-containers/nginx:latest`) - Should be REJECTED

Check the deployment status:
```bash
kubectl get deployments
```

You should see only the `nginx-test` deployment succeed, while the `nginx-test-gcr` deployment should be rejected by the webhook.

## Troubleshooting

### Check Webhook Logs

```bash
kubectl logs -n image-policy-system -l app=dockerhub-image-policy-webhook
```

### Check API Server Logs

```bash
kubectl logs -n kube-system -l component=kube-apiserver
```

### Webhook Not Working

1. Verify the webhook is running:
   ```bash
   kubectl get pods -n image-policy-system
   ```

2. Check the webhook endpoint is accessible:
   ```bash
   kubectl port-forward -n image-policy-system svc/dockerhub-image-policy-webhook 8443:443
   curl -k https://localhost:8443/health
   ```

3. Verify the ValidatingWebhookConfiguration:
   ```bash
   kubectl get validatingwebhookconfigurations dockerhub-image-policy-webhook-config -o yaml
   ```

### API Server Configuration Issues

If the API server fails to start after configuration changes:

1. Check the backup configuration:
   ```bash
   ls -l /etc/kubernetes/backups/
   ```

2. Restore the backup if needed:
   ```bash
   sudo cp /etc/kubernetes/backups/kube-apiserver-[TIMESTAMP].yaml /etc/kubernetes/manifests/kube-apiserver.yaml
   ```

## Uninstallation

To remove the webhook from your cluster:

```bash
kubectl delete -f k8s/webhook-manifests.yaml
kubectl delete namespace image-policy-system
```

To disable the ImagePolicyWebhook admission controller, restore the original API server configuration or remove the ImagePolicyWebhook from the --enable-admission-plugins flag.