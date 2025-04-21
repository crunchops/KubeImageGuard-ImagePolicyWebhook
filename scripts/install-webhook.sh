#!/bin/bash
# Script to install the DockerHub Image Policy Webhook

# Exit immediately if a command exits with a non-zero status
set -e

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Define image name
DEFAULT_IMAGE="techiescamp/kubeimageguard:latest"
IMAGE_NAME=${1:-$DEFAULT_IMAGE}

echo -e "${GREEN}Installing DockerHub Image Policy Webhook${NC}"
echo -e "${YELLOW}Using image: ${IMAGE_NAME}${NC}"

# Step 1: Generate certificates
echo -e "${GREEN}Step 1: Generating certificates...${NC}"
./scripts/generate-certificates.sh

# Step 2: Create the namespace
echo -e "${GREEN}Step 2: Creating image-policy-system namespace...${NC}"
kubectl create namespace image-policy-system || echo -e "${YELLOW}Namespace already exists${NC}"

# Step 3: Create the TLS secret
echo -e "${GREEN}Step 3: Creating TLS secret...${NC}"
kubectl create secret tls dockerhub-image-policy-webhook-certs \
    --cert=certs/webhook-server.crt \
    --key=certs/webhook-server.key \
    -n image-policy-system || echo -e "${YELLOW}Secret already exists${NC}"

# Step 4: Replace the image name in the webhook manifests
echo -e "${GREEN}Step 4: Updating webhook manifests with image name...${NC}"
sed -i "s|\${YOUR_IMAGE_NAME}|${IMAGE_NAME}|g" k8s/webhook-manifests.yaml

# Step 5: Apply the webhook manifests
echo -e "${GREEN}Step 5: Applying webhook manifests...${NC}"
kubectl apply -f k8s/webhook-manifests.yaml

echo -e "${GREEN}Webhook installation complete!${NC}"
echo ""
echo -e "${YELLOW}To test the webhook, apply the test deployments:${NC}"
echo "  kubectl apply -f k8s/test-deployment.yaml"
echo ""
echo -e "${YELLOW}To complete the API server configuration:${NC}"
echo "1. Copy required files to each control plane node:"
echo "   - k8s/image-policy-config.yaml -> /etc/kubernetes/image-policy-config.yaml"
echo "   - k8s/webhook-kubeconfig.yaml -> /etc/kubernetes/webhook-kubeconfig.yaml"
echo "   - certs/ca.crt -> /etc/kubernetes/pki/admission-webhook-ca.crt"
echo "   - certs/apiserver-client.crt -> /etc/kubernetes/pki/apiserver-client.crt"
echo "   - certs/apiserver-client.key -> /etc/kubernetes/pki/apiserver-client.key"
echo ""
echo "2. Run the API server configuration script on each control plane node:"
echo "   sudo ./scripts/update-apiserver-config.sh"