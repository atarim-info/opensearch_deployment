#!/bin/bash
# Script to generate self-signed certificates for OpenSearch

CERT_DIR=infra/opensearch-k8s/certs
mkdir -p $CERT_DIR

# Generate CA key and certificate
openssl genrsa -out $CERT_DIR/root-ca.key 4096
openssl req -x509 -new -nodes -key $CERT_DIR/root-ca.key -sha256 -days 3650 -out $CERT_DIR/root-ca.pem -subj "/CN=OpenSearch Root CA"

# Generate node key and CSR
openssl genrsa -out $CERT_DIR/esnode.key 2048
openssl req -new -key $CERT_DIR/esnode.key -out $CERT_DIR/esnode.csr -subj "/CN=esnode"

# Generate node certificate signed by CA
openssl x509 -req -in $CERT_DIR/esnode.csr -CA $CERT_DIR/root-ca.pem -CAkey $CERT_DIR/root-ca.key -CAcreateserial -out $CERT_DIR/esnode.pem -days 3650 -sha256

# Copy esnode.key to esnode-key.pem for compatibility
cp $CERT_DIR/esnode.key $CERT_DIR/esnode-key.pem

echo \"Certificates generated in $CERT_DIR:\"
echo \" - root-ca.pem\"
echo \" - esnode.pem\"
echo \" - esnode.key\"
echo \" - esnode-key.pem \(copy of esnode.key\)\"

echo \"To create Kubernetes secret, encode these files in base64 and update the secrets-opensearch-certs.yaml manifest.\"
base64 -w 0 $CERT_DIR/esnode.pem > $CERT_DIR/encoded_esnode.pem.txt 
base64 -w 0 $CERT_DIR/esnode-key.pem > $CERT_DIR/encoded_esnode-key.pem.txt 
base64 -w 0 $CERT_DIR/root-ca.pem > $CERT_DIR/encoded_root-ca.pem.txt 
# cat $CERT_DIR/encoded_esnode.pem.txt $CERT_DIR/encoded_esnode-key.pem.txt $CERT_DIR/encoded_root-ca.pem.txt
echo \n\n\n