#!/bin/bash

# Purpose: Create a Jamf Pro TLS identity that is signed by Charles Proxy
#  signing root to allow Jamf Pro communications with certificate pinning
#  to be decrypted with Charles.   

## ###################################################################
## Setup

# Starting point: 
# 1) a> Charles' .p12 root signing certificate has been exported to a directory.
#    b> The password used when exporting the p12 has been noted. 
# 2) Open terminal and cd into that directory. For example: 
cd "/Users/admin/Desktop/JNUC2019/cert"

# 3) Shorten the file name
# This is not necessary... I'm just doing it to make the rest of the 
#  commands shorter... 
cp charles-ssl-proxying.p12 charles.p12

## ###################################################################
## Export the private key from Charles' .p12 signing ident

# Export the Private key from .p12
openssl pkcs12 -in charles.p12 -nocerts -nodes -out charlesPrivate.pem
# You will be prompted for the import password

# Convert exported private key from .pem to .key format
openssl rsa -in charlesPrivate.pem -out charlesPrivate.key

## ###################################################################
## Export the public key from the signing identity .p12
openssl pkcs12 -in charles.p12 -clcerts -nokeys -out charlesPublic.crt

### ##################################################################
### ##################################################################
### Now we are ready to make an identity for use on the Jamf Pro server...

## ###################################################################
## Create a certificate signing request for the Jamf Pro Server

# This version creates a CSR with Subject Alternative Names
# openssl req -new -sha256 \
#   -key jamf.key \
#   -subj "/CN=Jamf Pro Server" \
#   -reqexts SAN \
#   -config <(cat /etc/ssl/openssl.cnf \
#     <(printf "\n[SAN]\nsubjectAltName=DNS:imac.local,DNS:jnuc.jamfse.io")) \
#   -out jamf.csr
    
## Create a new private key for Jamf Pro Server
# openssl genrsa -out jamf.key 2048
# openssl req \
#   -key jamf.key \
#   -out jamf.csr
#   -new \
#   -sha256 \
#   -nodes \
#   -subj "/CN=j" \
#   -addtrust serverAuth



echo '[ req ]
default_bits            = 1024
default_md              = sha1
default_keyfile         = privkey.pem
distinguished_name      = req_distinguished_name
attributes              = req_attributes
x509_extensions         = v3_ca # The extentions to add to the self signed cert
req_extensions          = v3_req
x509_extensions         = usr_cert
[ usr_cert ]
basicConstraints        = CA:FALSE
nsCertType              = client, server, email
keyUsage                = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage        = serverAuth, clientAuth, codeSigning, emailProtection
nsComment               = "OpenSSL Generated Certificate"
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid,issuer
[ v3_req ]
extendedKeyUsage        = serverAuth, clientAuth, codeSigning, emailProtection
basicConstraints        = CA:FALSE
keyUsage                = nonRepudiation, digitalSignature, keyEncipherment' > openssl.cnf


# This version creates a CSR with the Jamf Pro Server's host name in the certificate subject
openssl req \
  -out jamf.csr \
  -newkey rsa:2048 \
  -keyout jamf.key \
  -new \
  -sha256 \
  -subj "/CN=j" \
  -config openssl.cnf \
  -days 90
  
## ###################################################################
## Use the Charles Root signing identity to sign the Jamf Pro CSR

# Output = "jnuc.crt"
openssl x509 -req \
  -in jamf.csr \
  -CA charlesPublic.crt \
  -CAkey charlesPrivate.key \
  -CAcreateserial \
  -out jamf.crt \
  -days 90 \
  -sha256


## ###################################################################
## In the final step, we combine the files:
#   1) Our new jamf server private key
#   2) The signature we got using the Charles signing cert
#   3) The public cert of the Charles root so we have the full public trust chain in the file
openssl pkcs12 -export \
  -inkey jamf.key \
  -in jamf.crt \
  -certfile charlesPublic.crt \
  -out jamf.p12 
# This command will ask you to supply a password. You will need this to upload to Jamf Pro.
