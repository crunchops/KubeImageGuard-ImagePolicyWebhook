#!/bin/bash
# Script to generate certificates for ImagePolicyWebhook

# Exit immediately if a command exits with a non-zero status
set -e

# Create directories for certificates
CERT_DIR="./certs"
K8S_PKI_DIR="/etc/kubernetes/pki"
mkdir -p ${CERT_DIR}

echo "Generating certificates for ImagePolicyWebhook..."

# Generate CA key and certificate
echo "Generating CA key and certificate..."
openssl genrsa -out ${CERT_DIR}/ca.key 2048
openssl req -new -x509 -days 365 -key ${CERT_DIR}/ca.key \
    -subj "/CN=admission-webhook-ca" -out ${CERT_DIR}/ca.crt

# Generate server key and certificate signing request (CSR)
echo "Generating webhook server certificate..."
openssl genrsa -out ${CERT_DIR}/webhook-server.key 2048
openssl req -new -key ${CERT_DIR}/webhook-server.key \
    -subj "/CN=dockerhub-image-policy-webhook.image-policy-system.svc" \
    -out ${CERT_DIR}/webhook-server.csr

# Create certificate config file
cat > ${CERT_DIR}/cert-config.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = dockerhub-image-policy-webhook
DNS.2 = dockerhub-image-policy-webhook.image-policy-system
DNS.3 = dockerhub-image-policy-webhook.image-policy-system.svc
EOF

# Sign the server certificate with the CA
openssl x509 -req -days 365 -in ${CERT_DIR}/webhook-server.csr \
    -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial \
    -out ${CERT_DIR}/webhook-server.crt -extfile ${CERT_DIR}/cert-config.ext

# Generate client certificates for the API server
echo "Generating API server client certificates..."
openssl genrsa -out ${CERT_DIR}/apiserver-client.key 2048
openssl req -new -key ${CERT_DIR}/apiserver-client.key \
    -subj "/CN=apiserver-client" \
    -out ${CERT_DIR}/apiserver-client.csr

openssl x509 -req -days 365 -in ${CERT_DIR}/apiserver-client.csr \
    -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial \
    -out ${CERT_DIR}/apiserver-client.crt

# Create base64 encoded CA bundle
echo "Creating base64 encoded CA bundle..."
CA_BUNDLE=$(cat ${CERT_DIR}/ca.crt | base64 | tr -d '\n')

# Update manifest files with CA bundle
echo "Updating manifest files with CA bundle..."
sed -i "s|\${CA_BUNDLE}|${CA_BUNDLE}|g" k8s/webhook-manifests.yaml

echo "Certificate generation complete!"
echo ""
echo "The next steps are:"
echo "1. Copy the certificates to your Kubernetes nodes (typically to ${K8S_PKI_DIR}):"
echo "   - admission-webhook-ca.crt: ${CERT_DIR}/ca.crt -> ${K8S_PKI_DIR}/admission-webhook-ca.crt"
echo "   - apiserver-client.crt: ${CERT_DIR}/apiserver-client.crt -> ${K8S_PKI_DIR}/apiserver-client.crt" 
echo "   - apiserver-client.key: ${CERT_DIR}/apiserver-client.key -> ${K8S_PKI_DIR}/apiserver-client.key"
echo ""
echo "2. Create Kubernetes namespace and TLS secret:"
echo "   kubectl create namespace image-policy-system"
echo "   kubectl create secret tls dockerhub-image-policy-webhook-certs \\"
echo "       --cert=${CERT_DIR}/webhook-server.crt \\"
echo "       --key=${CERT_DIR}/webhook-server.key \\"
echo "       -n image-policy-system"
echo ""
echo "3. Apply the webhook configuration:"
echo "   kubectl apply -f k8s/webhook-manifests.yaml"
echo ""
echo "4. Copy the admission configuration files to your control plane nodes:"
echo "   - image-policy-config.yaml: k8s/image-policy-config.yaml -> /etc/kubernetes/image-policy-config.yaml"
echo "   - webhook-kubeconfig.yaml: k8s/webhook-kubeconfig.yaml -> /etc/kubernetes/webhook-kubeconfig.yaml"
echo ""
echo "5. Update kube-apiserver configuration using update-apiserver-config.sh script"