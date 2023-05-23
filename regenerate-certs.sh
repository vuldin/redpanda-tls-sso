#!/usr/bin/env bash

DOMAIN=$1

sudo chown -R $(whoami):$(whoami) redpanda-config
mkdir -p redpanda-config/{redpanda-0,redpanda-1,redpanda-2,redpanda-console}/certs
find redpanda-config/redpanda-*/certs -type d -exec rm -rf {} +
mkdir -p {ca-public,ca-private}
rm -f {ca-public,ca-private}/*

rm -f index.txt serial.txt
touch index.txt
echo '01' > serial.txt

# create the openssl certificate authority config file
cat > ca.cnf <<EOF
# OpenSSL CA configuration file
[ ca ]
default_ca = CA_default
[ CA_default ]
default_days = 365
database = index.txt
serial = serial.txt
default_md = sha256
copy_extensions = copy
unique_subject = no
# Used to create the CA certificate.
[ req ]
prompt=no
distinguished_name = distinguished_name
x509_extensions = extensions
[ distinguished_name ]
organizationName = Redpanda
commonName = Redpanda CA
[ extensions ]
keyUsage = critical,digitalSignature,nonRepudiation,keyEncipherment,keyCertSign
basicConstraints = critical,CA:true,pathlen:1
# Common policy for nodes and users.
[ signing_policy ]
organizationName = supplied
commonName = optional
# Used to sign node certificates.
[ signing_node_req ]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth,clientAuth
# Used to sign client certificates.
[ signing_client_req ]
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = clientAuth
EOF

openssl genrsa -out ca-private/ca.key 2048
chmod 400 ca-private/ca.key

# TODO what is this key for, it is never used
openssl req \
-new \
-x509 \
-config ca.cnf \
-key ca-private/ca.key \
-days 365 \
-batch \
-out ca-public/ca.key

openssl req \
-new -x509 \
-config ca.cnf \
-key ca-private/ca.key \
-days 365 \
-batch \
-out ca-public/ca.crt

for broker in redpanda-0 redpanda-1 redpanda-2 redpanda-console; do

cp ca-public/ca.crt redpanda-config/$broker/certs/

cat > redpanda-config/$broker/node.cnf <<EOF
# OpenSSL node configuration file
[ req ]
prompt=no
distinguished_name = distinguished_name
req_extensions = extensions
[ distinguished_name ]
organizationName = Redpanda
[ extensions ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $broker.$DOMAIN
IP.1 = 127.0.0.1
EOF

openssl genrsa -out redpanda-config/$broker/certs/node.key 2048
chmod 400 redpanda-config/$broker/certs/node.key

openssl req \
-new \
-config redpanda-config/$broker/node.cnf \
-key redpanda-config/$broker/certs/node.key \
-out redpanda-config/$broker/node.csr \
-batch

openssl ca \
-config ca.cnf \
-keyfile ca-private/ca.key \
-cert redpanda-config/$broker/certs/ca.crt \
-policy signing_policy \
-extensions signing_node_req \
-out redpanda-config/$broker/certs/node.crt \
-outdir redpanda-config/$broker/certs/ \
-in redpanda-config/$broker/node.csr \
-batch

openssl x509 -in redpanda-config/$broker/certs/node.crt -text | grep "X509v3 Subject Alternative Name" -A 1

rm redpanda-config/$broker/{node.cnf,node.csr}

done

find redpanda-config/*/certs -type f -name "*.pem" -delete
sudo chown -R 101:101 redpanda-config/{redpanda-0,redpanda-1,redpanda-2}
rm ca.cnf index.txt index.txt.attr index.txt.attr.old index.txt.old serial.txt serial.txt.old

