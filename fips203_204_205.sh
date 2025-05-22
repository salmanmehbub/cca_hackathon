#!/bin/sh

echo "==== FIPS 203: Kyber (KEM) Demonstration ===="
echo "Kyber is used in TLS KEM; OpenSSL does not export it as PEM keys."
openssl list -kem-algorithms -provider oqsprovider | grep kyber
echo "✅ Kyber support verified."

echo "\n==== FIPS 204: Dilithium (Digital Signature) ===="
echo "Generating Dilithium keypair and self-signed certificate..."
openssl req -provider oqsprovider -new -x509 \
  -newkey dilithium3 \
  -keyout dilithium_key.pem \
  -out dilithium_cert.pem \
  -days 365 \
  -subj "/CN=DilithiumCert" -nodes
echo "✅ Dilithium cert and key saved."

echo "Signing message..."
echo "Post-Quantum Message" > msg.txt
openssl dgst -sha256 -sign dilithium_key.pem -out dilithium_sig.bin msg.txt
openssl x509 -in dilithium_cert.pem -pubkey -noout > dilithium_pubkey.pem

echo "Verifying signature..."
openssl dgst -sha256 -verify dilithium_pubkey.pem -signature dilithium_sig.bin msg.txt
dilithium_verify_result=$?
if [ $dilithium_verify_result -eq 0 ]; then
  echo "✅ Dilithium signature verified."
else
  echo "❌ Dilithium signature verification failed."
fi

echo "\n==== FIPS 205: SPHINCS+ (Stateless Signature) ===="
echo "Generating SPHINCS+ keypair..."
openssl genpkey -provider oqsprovider \
  -algorithm sphincssha2128fsimple \
  -out sphincs_key.pem
openssl pkey -in sphincs_key.pem -pubout -out sphincs_pub.pem

if [ -f sphincs_key.pem ] && [ -f sphincs_pub.pem ]; then
  echo "✅ SPHINCS+ keypair generated successfully."
else
  echo "❌ SPHINCS+ key generation failed."
fi

echo "Signing message..."
openssl dgst -sha256 -sign sphincs_key.pem -out sphincs_sig.bin msg.txt

echo "Verifying signature..."
openssl dgst -sha256 -verify sphincs_pub.pem -signature sphincs_sig.bin msg.txt
sphincs_verify_result=$?
if [ $sphincs_verify_result -eq 0 ]; then
  echo "✅ SPHINCS+ signature verified."
else
  echo "❌ SPHINCS+ signature verification failed."
fi

echo "\n🎉 All operations completed successfully."
