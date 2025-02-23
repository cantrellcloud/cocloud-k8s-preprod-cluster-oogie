# Deploying an Intermediate Subordinate CA on Ubuntu 2024.04 LTS

- [Deploying an Intermediate Subordinate CA on Ubuntu 2024.04 LTS](#deploying-an-intermediate-subordinate-ca-on-ubuntu-202404-lts)
  - [Tips](#tips)
    - [Verify a Certificate and Key](#verify-a-certificate-and-key)
  - [COCloud Issuing Certificate Authority 03](#cocloud-issuing-certificate-authority-03)
    - [Create SubCA Initialization Script](#create-subca-initialization-script)
    - [Submit Request to Cantrell Cloud Certificate Authority](#submit-request-to-cantrell-cloud-certificate-authority)
    - [Other Information](#other-information)
    - [Next Steps](#next-steps)

---

## Tips

### Verify a Certificate and Key

```bash
#! /bin/bash
# Argument validation check
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <certificate> <certificate-key>"
  exit 1
fi

openssl rsa  -noout -modulus -in ${2} | openssl md5
openssl x509 -noout -modulus -in ${1} | openssl md5
echo Do the above hashes match?
echo
```

## COCloud Issuing Certificate Authority 03

This subordinate Certificate Authority will be created with *CA=TRUE and pathlen:3* so that it may sign
CA requests for Kubernetes clusters. Kubernetes clusters need root CA certificates to auto
generate all the certificates needed to initialize a cluster.

### Create SubCA Initialization Script

```bash
touch $HOME/init-subca03.sh
chmod +x $HOME/init-subca03.sh

vi $HOME/init-subca03.sh
```

```text
#!/bin/bash
clear
echo BEGIN
echo
echo -------------------------------
echo Removing exisiting subCA...
rm -rf /opt/subca03/
echo
echo -------------------------------
echo Setting variables...
export CaName=cocloud-subca03
export CaCertName='Cantrell Cloud Issuing Certificate Authority 03'
export dir=/opt/subca03
echo
echo -------------------------------
echo Making directory and file structure...
mkdir -p $dir/{certs,crl,newcerts,private,requests}
touch $dir/index.txt
echo 1000 > $dir/serial
echo -------------------------------
echo Setting permissions...
chmod 600 $dir
echo
echo -------------------------------
echo Create Openssl configuration file...
tee $dir/requests/$CaName.cnf <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
CaName            = $CaName
CertificateName   = $CaCertName
dir               = /$dir/$CaName
certs             = $dir/certs
crl_dir           = $dir/crl
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
RANDFILE          = $dir/private/.rand

# The root key and root certificate.
private_key       = $dir/private/$RootCaName-key.pem
certificate       = $dir/certs/$RootCaName.pem

# For certificate revocation lists.
crlnumber         = $dir/crlnumber
crl               = $dir/crl/subca.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 3650
preserve          = no
policy            = policy_loose

copy_extensions   = copy

[ policy_strict ]
# The root CA should only sign subca certificates that match.
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ policy_loose ]
# Allow the subca CA to sign a more diverse range of certificates.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_subca_ca

[ req_distinguished_name ]
commonName                      = Common Name
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
emailAddress                    = Email Address

# Optionally, specify some defaults.
commonName_default              = $CaCertName
countryName_default             = US
stateOrProvinceName_default     = Florida
localityName_default            = New Port Richey
0.organizationName_default      = Cantrell Cloud ES
organizationalUnitName_default  = InfoSys
emailAddress_default            =

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_subca_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
# Setting pathlen to 1 so that this SubCA can sign CA requests for Kubernetes clusters
basicConstraints = critical, CA:true, pathlen:1
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ usr_cert ]
basicConstraints = CA:FALSE
nsCertType = client, email
nsComment = "COCloud OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, emailProtection
authorityInfoAccess = URI:http://pki.cantrell.cloud/pki/$CaName$CaCertName.crt
crlDistributionPoints = URI:http://pki.cantrell.cloud/pki/$CaName.crl

[ server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "COCloud OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
authorityInfoAccess = URI:http://pki.cantrell.cloud/pki/$CaName$CaCertName.crt
crlDistributionPoints = URI:http://pki.cantrell.cloud/pki/$CaName.crl
#subjectAltName = @alt_names

#[ alt_names ]
#DNS.1 = example.com
#DNS.2 = www.example.com
#DNS.3 = m.example.com

[ crl_ext ]
authorityKeyIdentifier=keyid:always
EOF
echo
echo -------------------------------
echo
echo Generate Certificate Request...
echo -------------------------------
echo Creating Private Key...
openssl genrsa \
  -aes256 \
  -out $dir/private/$CaName-key.pem \
  4096
echo
echo -------------------------------
echo Creating certificate request...
openssl req -new \
  -extensions v3_subca_ca \
  -out $dir/requests/$CaName.csr \
  -key $dir/private/$CaName-key.pem \
  -config $dir/$CaName.cnf
echo
echo -------------------------------
echo If using Windows or other external Certificate Authority to sign the request
echo Use the .req request file to generate the signed certificate from the external CA
echo
echo -------------------------------
echo Copy request file to caadmin home
cp $dir/requests/$CaName.csr /home/caadmin/$CaName.req
echo
echo -------------------------------
echo Change permissions to caadmin
chown caadmin:caadmin /home/caadmin/$CaName.req
echo END
echo
```

### Submit Request to Cantrell Cloud Certificate Authority



### Other Information

```bash
# If using Ubuntu/Linux Certificate Authority to sign the request
#openssl x509 -req \
# -in $dir/requests/$CaName.csr \
# -CA $dir/cacert.pem \
# -CAkey $dir/private/cakey.pem \
# -out $dir/certs/$CaName.crt \
# -extensions v3_ca \
# -extfile $dir/$CaName.cnf
#cat $dir/certs/$CaName.crt $dir/private/$CaName-key.pem > $dir/certs/$CaName.pem
```

### Next Steps

Submit additional intermediate subordinate certificate authorities requests to this SubCA
for use with COCloud Kerbernetes Clusters to allow intra-cluster auto generation of certificates.

A request should be submitted for each cluster being deployed. The ca.key file should not have
a password set. See build guide *BG-011 Deploying Kubernetes on Ubuntu 2024.04 LTS.md* for more
information.
