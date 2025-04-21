#!/bin/bash
# Script to update kube-apiserver configuration for ImagePolicyWebhook

# Exit immediately if a command exits with a non-zero status
set -e

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Define paths
APISERVER_CONFIG="/etc/kubernetes/manifests/kube-apiserver.yaml"
BACKUP_DIR="/etc/kubernetes/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root${NC}"
    exit 1
fi

# Check if kube-apiserver.yaml exists
if [ ! -f "${APISERVER_CONFIG}" ]; then
    echo -e "${RED}Error: kube-apiserver.yaml not found at ${APISERVER_CONFIG}${NC}"
    echo -e "${YELLOW}This script is designed for kubeadm-based Kubernetes clusters.${NC}"
    echo -e "${YELLOW}For other Kubernetes distributions, please modify the API server configuration manually.${NC}"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p ${BACKUP_DIR}

# Backup the current kube-apiserver.yaml
echo -e "${GREEN}Creating backup of kube-apiserver.yaml...${NC}"
cp ${APISERVER_CONFIG} ${BACKUP_DIR}/kube-apiserver-${TIMESTAMP}.yaml
echo -e "${GREEN}Backup created at: ${BACKUP_DIR}/kube-apiserver-${TIMESTAMP}.yaml${NC}"

# Check if ImagePolicyWebhook is already enabled
if grep -q "\-\-enable-admission-plugins=.*ImagePolicyWebhook" ${APISERVER_CONFIG}; then
    echo -e "${YELLOW}ImagePolicyWebhook already included in --enable-admission-plugins flag${NC}"
else
    echo -e "${GREEN}Adding ImagePolicyWebhook to --enable-admission-plugins flag...${NC}"
    # Add ImagePolicyWebhook to the existing enable-admission-plugins flag
    sed -i 's/--enable-admission-plugins=/--enable-admission-plugins=ImagePolicyWebhook,/' ${APISERVER_CONFIG}
fi

# Check if admission-control-config-file is already set
if grep -q "\-\-admission-control-config-file=" ${APISERVER_CONFIG}; then
    echo -e "${YELLOW}--admission-control-config-file flag is already set${NC}"
else
    echo -e "${GREEN}Adding --admission-control-config-file flag...${NC}"
    # Find the line with the command array and add the new flag after it
    line_number=$(grep -n "command:" ${APISERVER_CONFIG} | cut -d ":" -f 1)
    insert_after=$((line_number + 1))
    sed -i "${insert_after}i\    - --admission-control-config-file=/etc/kubernetes/image-policy-config.yaml" ${APISERVER_CONFIG}
fi

# Verify the changes
echo -e "${GREEN}Configuration updated successfully.${NC}"
echo -e "${YELLOW}Changes to kube-apiserver.yaml require the API server to restart,${NC}"
echo -e "${YELLOW}which should happen automatically since the file is in the manifests directory.${NC}"
echo -e "${YELLOW}The changes will take effect after the kubelet notices the file change (usually within a minute).${NC}"
echo ""
echo -e "${GREEN}Verify the kube-apiserver pod restarts properly:${NC}"
echo "  kubectl get pods -n kube-system | grep kube-apiserver"
echo ""
echo -e "${GREEN}If there are any issues, you can restore the backup:${NC}"
echo "  cp ${BACKUP_DIR}/kube-apiserver-${TIMESTAMP}.yaml ${APISERVER_CONFIG}"
echo ""
echo -e "${GREEN}Make sure the following files exist:${NC}"
echo "  - /etc/kubernetes/image-policy-config.yaml"
echo "  - /etc/kubernetes/webhook-kubeconfig.yaml"
echo "  - /etc/kubernetes/pki/admission-webhook-ca.crt"
echo "  - /etc/kubernetes/pki/apiserver-client.crt"
echo "  - /etc/kubernetes/pki/apiserver-client.key"