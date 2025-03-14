#!/bin/bash
clear
echo BEGIN
echo
echo -------------------------------
echo Removing exisiting subCA...
rm -rf /opt/copinekubeca01/
echo
echo -------------------------------
echo Setting variables...
export CaName=copinekubeca01
export CaCertName='COPINE Kubernetes Issuing Certificate Authority 01'
export dir=/opt/$CaName
export RootCaName=cocloud-subca03
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
tee $dir/$CaName.cnf <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
CaName            = $CaName
CertificateName   = $CaCertName
dir               = $dir
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
policy            = policy_strict

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
  -config $dir/requests/$CaName.cnf
echo
echo -------------------------------
echo If using Windows or other external Certificate Authority to sign the request
echo Use the .req request file to generate the signed certificate from the external CA
echo
echo -------------------------------
echo Copy request file to caadmin home
echo #cp $dir/requests/$CaName.csr /home/kadmin/kubeconf/build/$CaName.req
echo
echo -------------------------------
echo Change permissions to kadmin
echo #chown kadmin:kadmin /home/kadmin/kubeconf/build/$CaName.req
echo END
echo
