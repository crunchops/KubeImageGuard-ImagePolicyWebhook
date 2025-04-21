# KubeImageGuard: Kubernetes DockerHub Image Policy Webhook

This webhook validates container images and only allows those from DockerHub repositories in your Kubernetes cluster.

## Overview

The webhook integrates with Kubernetes admission controllers to intercept and validate resource creation and update requests. It checks all container images referenced in resources like Pods, Deployments, StatefulSets, etc., and rejects any that are not from DockerHub.

## Features

- Validates container images in all workload resources
- Only allows images from DockerHub repositories
- Provides web UI for monitoring webhook activity
- Logs all admission requests and decisions
- Handles edge cases and provides clear error messages

## Docker Support

This application can be containerized for easy deployment. We've included:

- `Dockerfile` - For building the application container
- `docker-compose.yml` - For local testing
- `deployment-guide.md` - Detailed instructions for building, publishing, and deploying

### Pre-built Docker Image

A pre-built Docker image is available on DockerHub:

```bash
docker pull techiescamp/kubeimageguard:latest
```

### Building Locally

To quickly build and test with Docker:

```bash
# Build the image
docker build -t techiescamp/kubeimageguard:latest .

# Run the container
docker run -p 5000:5000 -e SESSION_SECRET=test_secret techiescamp/kubeimageguard:latest
```

For more detailed Docker instructions, see [deployment-guide.md](deployment-guide.md).

## Kubernetes Deployment

### Prerequisites

- Kubernetes cluster with admission webhook support
- TLS certificates for secure webhook communication
- kubectl access to your cluster

### Setting up TLS certificates

For the webhook to work, you need to generate TLS certificates and create a Kubernetes secret:

```bash
# Create a directory for certificates
mkdir -p certs
cd certs

# Generate CA key and certificate
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -subj "/CN=admission-webhook-ca" -out ca.crt

# Generate server key and certificate signing request (CSR)
openssl genrsa -out webhook-server.key 2048
openssl req -new -key webhook-server.key -subj "/CN=dockerhub-image-policy-webhook.image-policy-system.svc" -out webhook-server.csr

# Create certificate config file
cat > cert-config.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = dockerhub-image-policy-webhook
DNS.2 = dockerhub-image-policy-webhook.image-policy-system
DNS.3 = dockerhub-image-policy-webhook.image-policy-system.svc
EOF

# Sign the CSR with our CA
openssl x509 -req -days 365 -in webhook-server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out webhook-server.crt -extfile cert-config.ext

# Create the namespace
kubectl create namespace image-policy-system

# Create a secret containing the server certificate and key
kubectl create secret tls dockerhub-image-policy-webhook-certs \
    --cert=webhook-server.crt \
    --key=webhook-server.key \
    -n image-policy-system

# Get base64 encoded CA bundle for the webhook configuration
CA_BUNDLE=$(cat ca.crt | base64 | tr -d '\n')
