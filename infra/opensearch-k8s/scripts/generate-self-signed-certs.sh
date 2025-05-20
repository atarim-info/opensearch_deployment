#!/bin/bash
# Script to generate self-signed certificates for OpenSearch

CERT_DIR=infra/opensearch-k8s/certs
mkdir -p $CERT_DIR

# 1. Generate CA Key and Certificate
echo "Generating CA private key..."
openssl genpkey -algorithm RSA -out "${CERT_DIR}/root-ca.key" -pkeyopt rsa_keygen_bits:2048
# openssl genrsa -out $CERT_DIR/root-ca.key 4096

echo "Generating CA certificate..."
openssl req -new -x509 -key "${CERT_DIR}/root-ca.key" -sha256 -days 3650 -out "${CERT_DIR}/root-ca.pem" -subj "/C=US/ST=CA/L=SanFrancisco/O=ExampleOrg/CN=ExampleRootCA"
# openssl req -x509 -new -nodes -key $CERT_DIR/root-ca.key -sha256 -days 3650 -out $CERT_DIR/root-ca.pem -subj "/CN=OpenSearch Root CA"

# 2. Generate OpenSearch Key and CSR
# Generate node key and CSR
echo "Generating OpenSearch private key..."
openssl genpkey -algorithm RSA -out "${CERT_DIR}/esnode.key" -pkeyopt rsa_keygen_bits:2048
# openssl genrsa -out $CERT_DIR/esnode.key 2048

echo "Generating OpenSearch CSR..."
openssl req -new -key "${CERT_DIR}/esnode.key" -out "${CERT_DIR}/esnode.csr" -subj "/C=US/ST=CA/L=SanFrancisco/O=ExampleOrg/CN=opensearch.local"
# openssl req -new -key $CERT_DIR/esnode.key -out $CERT_DIR/esnode.csr -subj "/CN=esnode"

# 3. Sign the OpenSearch CSR with the CA to create the OpenSearch Certificate
# Generate node certificate signed by CA
echo "Signing OpenSearch certificate with CA..."
openssl x509 -req -in "${CERT_DIR}/esnode.csr" -CA "${CERT_DIR}/root-ca.pem" -CAkey "${CERT_DIR}/root-ca.key" -CAcreateserial -out "${CERT_DIR}/esnode.pem" -days 365 -sha256
# openssl x509 -req -in $CERT_DIR/esnode.csr -CA $CERT_DIR/root-ca.pem -CAkey $CERT_DIR/root-ca.key -CAcreateserial -out $CERT_DIR/esnode.pem -days 3650 -sha256

# Copy esnode.key to esnode-key.pem for compatibility
cp $CERT_DIR/esnode.key $CERT_DIR/esnode-key.pem

# 4. Generate OpenSearch Dashboards Key and CSR
echo "Generating OpenSearch Dashboards private key..."
openssl genpkey -algorithm RSA -out "${CERT_DIR}/dashboards.key" -pkeyopt rsa_keygen_bits:2048

echo "Generating OpenSearch Dashboards CSR..."
openssl req -new -key "${CERT_DIR}/dashboards.key" -out "${CERT_DIR}/dashboards.csr" -subj "/C=US/ST=CA/L=SanFrancisco/O=ExampleOrg/CN=opensearch-dashboards.local"

# 5. Sign the OpenSearch Dashboards CSR with the CA to create the Dashboards Certificate
echo "Signing OpenSearch Dashboards certificate with CA..."
openssl x509 -req -in "${CERT_DIR}/dashboards.csr" -CA "${CERT_DIR}/root-ca.pem" -CAkey "${CERT_DIR}/root-ca.key" -CAcreateserial -out "${CERT_DIR}/dashboards.pem" -days 365 -sha256

# 6. Clean up CSR files
rm "${CERT_DIR}/esnode.csr"
rm "${CERT_DIR}/dashboards.csr"

echo "Certificates generated successfully."
echo "CA Certificate: ${CERT_DIR}/root-ca.pem"
echo "OpenSearch Certificate: ${CERT_DIR}/esnode.pem"
echo "OpenSearch Key: ${CERT_DIR}/esnode.key"
echo "OpenSearch Key: ${CERT_DIR}/esnode-key.pem (copy of esnode.key)"
echo "OpenSearch Dashboards Key: ${CERT_DIR}/dashboards.key"
echo "OpenSearch Dashboards Certificate: ${CERT_DIR}/dashboards.pem"

# echo \"Certificates generated in $CERT_DIR:\"
# echo \" - root-ca.pem\"
# echo \" - esnode.pem\"
# echo \" - esnode.key\"
# echo \" - esnode-key.pem \(copy of esnode.key\)\"
# echo \" - dashboards.pem\"
# echo \" - dashboards.key\"

# Adjusting permissions
chmod 700 $CERT_DIR
chmod 600 $CERT_DIR/{*.key,*.pem}

echo "Encoding certificates for Kubernetes secret..."
echo "To create Kubernetes secret, encode these files in base64 and update the secrets-opensearch-certs.yaml manifest."
base64 -w 0 $CERT_DIR/root-ca.pem > $CERT_DIR/encoded_root-ca.pem.txt 
base64 -w 0 $CERT_DIR/esnode.pem > $CERT_DIR/encoded_esnode.pem.txt 
base64 -w 0 $CERT_DIR/esnode-key.pem > $CERT_DIR/encoded_esnode-key.pem.txt 
base64 -w 0 $CERT_DIR/dashboards.pem > $CERT_DIR/encoded_dashboards.pem.txt 
base64 -w 0 $CERT_DIR/dashboards.key > $CERT_DIR/encoded_dashboards.key.txt 

echo "Replacing placeholders in secrets.yaml with base64 encoded values..."

BASE_DIR=infra/opensearch-k8s/base
SECRETS_YAML=$BASE_DIR/secrets.yaml
cp $SECRETS_YAML $SECRETS_YAML.bak

sed -e "s/{{BASE64-ENCODED-ROOT-CA-CERT}}/$(<$CERT_DIR/encoded_root-ca.pem.txt)/" \
    -e "s/{{BASE64-ENCODED-ESNODE-PEM}}/$(<$CERT_DIR/encoded_esnode.pem.txt)/" \
    -e "s/{{BASE64-ENCODED-ESNODE-KEY-PEM}}/$(<$CERT_DIR/encoded_esnode-key.pem.txt)/" \
    -e "s/{{BASE64-ENCODED-DASHBOARDS-PEM}}/$(<$CERT_DIR/encoded_dashboards.pem.txt)/" \
    -e "s/{{BASE64-ENCODED-DASHBOARDS-KEY}}/$(<$CERT_DIR/encoded_dashboards.key.txt)/" \
     $BASE_DIR/secrets-template.yaml > $SECRETS_YAML
echo "Kubernetes secret manifest updated with base64 encoded values."
