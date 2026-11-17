#!/bin/bash
# original at https://github.com/confluentinc/cp-docker-images/blob/5.3.1-post/examples/kafka-cluster-ssl/secrets/create-certs.sh
set -o nounset \
    -o errexit \
    -o verbose \
    -o xtrace

rm -f tool-test.*
rm -f kafka.*.jks
rm -f snakeoil-ca-*

# Generate CA key
openssl req -new -x509 -keyout snakeoil-ca-1.key -out snakeoil-ca-1.crt -days 365 -subj '/CN=localhost/OU=TEST/O=KT' -addext 'subjectAltName = DNS:localhost' -passin pass:tooltooltool -passout pass:tooltooltool

for i in broker1
do
	echo $i
	echo ">> 0 <<"
	keytool -genkey -noprompt \
				 -alias $i \
				 -dname "CN=localhost, OU=TEST, O=KT" \
				 -ext "SAN=DNS:localhost" \
				 -keystore kafka.$i.keystore.jks \
				 -keyalg RSA \
				 -storepass tooltooltool \
				 -keypass tooltooltool
	# Create CSR, sign the key and import back into keystore
	keytool -keystore kafka.$i.keystore.jks -alias $i -certreq -file $i.csr -storepass tooltooltool -keypass tooltooltool
	openssl x509 -req -extfile <(printf "subjectAltName=DNS:localhost") -CA snakeoil-ca-1.crt -CAkey snakeoil-ca-1.key -in $i.csr -out $i-ca1-signed.crt -days 9999 -CAcreateserial -passin pass:tooltooltool
	keytool -keystore kafka.$i.keystore.jks -alias CARoot -import -file snakeoil-ca-1.crt -storepass tooltooltool -keypass tooltooltool
	keytool -keystore kafka.$i.keystore.jks -alias $i -import -file $i-ca1-signed.crt -storepass tooltooltool -keypass tooltooltool
	# Create truststore and import the CA cert.
	keytool -keystore kafka.$i.truststore.jks -alias CARoot -import -file snakeoil-ca-1.crt -storepass tooltooltool -keypass tooltooltool

  echo "tooltooltool" > ${i}_sslkey_creds
  echo "tooltooltool" > ${i}_keystore_creds
  echo "tooltooltool" > ${i}_truststore_creds
done

# generate public/private key pair for tool
openssl genrsa -out tool-test.key 2048
openssl req -new -key tool-test.key -out tool-test.csr -subj '/CN=localhost/OU=TEST/O=KT' -addext 'subjectAltName = DNS:localhost'
openssl x509 -req -extfile <(printf "subjectAltName=DNS:localhost") -days 9999 -in tool-test.csr -CA snakeoil-ca-1.crt -CAkey snakeoil-ca-1.key -CAcreateserial -out tool-test.crt
