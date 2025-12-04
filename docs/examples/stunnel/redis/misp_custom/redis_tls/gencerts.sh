#!/bin/bash

# --- CA ---
openssl genrsa -out ca-key.pem 4096

openssl req -x509 -new -nodes \
  -key ca-key.pem \
  -sha256 -days 3650 \
  -subj "/C=AU/ST=VIC/L=Melbourne/O=Example/OU=CA/CN=Example-CA" \
  -out ca.pem


# --- SERVER CERT ---
openssl genrsa -out server-key.pem 2048

openssl req -new \
  -key server-key.pem \
  -subj "/C=AU/ST=VIC/L=Melbourne/O=Example/OU=Server/CN=redis" \
  -addext "subjectAltName=DNS:redis,DNS:localhost,IP:127.0.0.1" \
  -out server.csr

openssl x509 -req \
  -in server.csr \
  -CA ca.pem \
  -CAkey ca-key.pem \
  -CAcreateserial \
  -sha256 -days 825 \
  -out server-cert.pem \
  -extfile <(printf "subjectAltName=DNS:redis,DNS:localhost,IP:127.0.0.1")


# --- CLIENT CERT ---
openssl genrsa -out client-key.pem 2048

openssl req -new \
  -key client-key.pem \
  -subj "/C=AU/ST=VIC/L=Melbourne/O=Example/OU=Client/CN=client" \
  -out client.csr

openssl x509 -req \
  -in client.csr \
  -CA ca.pem \
  -CAkey ca-key.pem \
  -CAcreateserial \
  -sha256 -days 825 \
  -out client-cert.pem


# --- PERMS ---
chmod 600 ca-key.pem server-key.pem client-key.pem
chmod 644 ca.pem server-cert.pem client-cert.pem

