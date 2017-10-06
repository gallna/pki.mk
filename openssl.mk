SHELL = /bin/bash
.DEFAULT_GOAL := info

certs = server client ipsec
intermediate := $(shell basename $(CURDIR))
# Intermediate certificate
random_word = $(shell shuf -n $(1) /usr/share/dict/words | sed 's/[^a-zA-Z]//g' | paste -sd"$(2)")
random_name = $(shell curl -sS pseudorandom.name | sed 's/[^a-zA-Z]//g' | tr '[:upper:] ' '[:lower:]$(1)')
pseudorandom = $(shell curl -sS pseudorandom.name)
export KEY_ORGUNIT = $(shell basename $(CURDIR)) CA
export KEY_CN = $(call random_name, )
define info =
	@echo "ca:              $(ca)"
	@echo "intermediate: $(intermediate)"
	@echo "certificates: $(certificates)"
	@echo "random_word:     $(call random_word,2,-)"
	@echo "random_name:     $(call random_name, )"
	@echo "pseudorandom:    $(call pseudorandom)"
	@echo "CURDIR:          $(CURDIR)"
endef
clean:
	rm -f **/crlnumber **/serial **/serial.* **/index.* **/*.{pem,csr,crt,key,p12}
	rmdir $(dirs)
	
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Intermediate certificate - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

# Create a key and certificate signing request (CSR) in one command
# openssl genrsa -nodes -aes256 -out private/intermediate.key.pem 4096
# -keyout instead of -key allows create key and csr in one command,
# certificate signing request (CSR)
# extensions: v3_intermediate_ca config: root
%.csr.pem %.key.pem: | %.cnf
	openssl req -nodes -new -sha256 -batch \
		-config $*.cnf \
		-keyout $*.key.pem \
		-out $*.csr.pem
	chmod 644 $*.key.pem

%.cert.pem:
	cd ./.. && $(MAKE) $(intermediate)/$@

%.chain.pem:
	cd ./.. && $(MAKE) $(intermediate)/$@

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Create server/user key  ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

# Create a key and certificate signing request (CSR) in one command
# openssl genrsa -nodes -aes256 -out private/${KEY_FQDN}.key.pem 2048
# -keyout instead of -key allows create key and csr in one command,
# together with -nodes password can be ommited
$(certs)/%.key.pem $(certs)/%.csr.pem:
	cd $(@D) && $(MAKE) $(@F)

# To create a certificate, use the intermediate CA to sign the CSR.
# If the certificate is going to be used on a server, use the server_cert extension.
# If the certificate is going to be used for user authentication, use the usr_cert extension.

# -subj "/C=$(KEY_COUNTRY)/ST=$(KEY_PROVINCE)/L=$(KEY_LOCALITY)/O=$(KEY_ORG)/OU=$(KEY_ORGUNIT)/CN=$(KEY_CN)"
# extensions: server_cert config: intermediate
$(certs)/%.cert.pem:
	openssl ca -config $(intermediate).cnf \
		-batch -days 375 -notext -md sha256 \
		-extensions server_cert \
		-in $(@D)/$(@F).csr.pem \
		-out $(@D)/$(@F).cert.pem
	chmod 644 $(@D)/$(@F).cert.pem

# Create a certificate chain
$(certs)/%.chain.pem: $(intermediate).chain.pem
	cat $(intermediate).chain.pem $(@D)/$(@F).cert.pem > $@

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Private Key ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

# Private Key(.key)
# -----BEGIN RSA PRIVATE KEY-----
# -----END RSA PRIVATE KEY-----

# Create a Private Key
%.key:
	openssl genrsa -des3 -out domain.key 2048

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Self-Signed Certificate ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# Base64-encoded X.509 Certificate (.cer or .crt)
# Privacy-enhanced Electronic Mail (.pem)

# PEM format is a refinement of base64 encoding.
# -----BEGIN RSA PRIVATE KEY-----
# -----END RSA PRIVATE KEY-----
# PEM for storing Public Key
# -----BEGIN PUBLIC KEY-----
# -----END PUBLIC KEY-----

# Generate a Self-Signed Certificate
%.crt:
	openssl req \
		-newkey rsa:2048 -nodes -keyout domain.key \
		-x509 -days 365 -out domain.crt

# Generate a Private Key and a CSR
%.csr:
	openssl req -newkey rsa:2048 -nodes \
		-keyout $*.key -out $*.csr

# Generate a Self-Signed Certificate from an Existing Private Key
%.crt: %.key
	openssl req \
	-key domain.key \
	-new \
	-x509 -days 365 -out domain.crt

# Generate a Self-Signed Certificate from an Existing Private Key and CSR
%.crt: %.key %.csr
	openssl x509 \
	       -signkey domain.key \
	       -in domain.csr \
	       -req -days 365 -out domain.crt

# Generate a Self-Signed Certificate from an Existing Private Key and CSR
%.crt: | %.key %.csr
	openssl x509 -req -days 365 \
		-out $*.crt -signkey $*.key -in $*.csr

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Certificate Signing Request (CSR) - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

# Certificate and CSR files are encoded in PEM format

# Generate a CSR from an Existing Certificate and Private Key
%.csr: | %.key %.crt
	openssl x509 \
	       -in domain.crt \
	       -signkey domain.key \
	       -x509toreq -out domain.csr

# Generate a CSR from an Existing Private Key
%.csr: %.key
	openssl req -new -key $*.key \
        -out $*.csr

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - View Certificates - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

view/%.csr:
	openssl req -text -noout -verify -in domain.csr

view/%.crt:
	openssl x509 -text -noout -in domain.crt

verify/%.crt:
	openssl verify -verbose -CAFile ca.crt domain.crt


# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Verify Certificates ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

# Verify a Private Key
verify/%.key:
	openssl rsa -check -in domain.key

# Verify a Private Key Matches a Certificate and CSR
verify/%.key: | %.crt %.csr
	openssl rsa -noout -modulus -in domain.key | openssl md5
	openssl x509 -noout -modulus -in domain.crt | openssl md5
	openssl req -noout -modulus -in domain.csr | openssl md5

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Convert Certificate Formats ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

# Convert PEM to DER
%.der: | %.pem
	openssl x509 \
       -in domain.crt \
       -outform der -out domain.der

# Convert DER to PEM
# Use this command if you want to convert a DER-encoded certificate (domain.der) to a PEM-encoded certificate (domain.crt):
%.pem: | %.der
	openssl x509 \
      -inform der -in domain.der \
      -out domain.crt

# Convert PEM to PKCS7
# Use this command if you want to add PEM certificates (domain.crt and ca-chain.crt) to a PKCS7 file (domain.p7b):
# Note that you can use one or more -certfile options to specify which certificates to add to the PKCS7 file.
# PKCS7 files, also known as P7B, are typically used in Java Keystores and Microsoft IIS (Windows). They are ASCII files which can contain certificates and CA certificates.
%.p7b: | %.pem
	openssl crl2pkcs7 -nocrl \
      -certfile domain.crt \
      -certfile ca-chain.crt \
      -out domain.p7b

# Convert PKCS7 to PEM
# Use this command if you want to convert a PKCS7 file (domain.p7b) to a PEM file:
# Note that if your PKCS7 file has multiple items in it (e.g. a certificate and a CA intermediate certificate), the PEM file that is created will contain all of the items in it.
%.pem: | %.p7b
	openssl pkcs7 \
      -in domain.p7b \
      -print_certs -out domain.crt

# Convert PEM to PKCS12
# Use this command if you want to take a private key (domain.key) and a certificate (domain.crt), and combine them into a PKCS12 file (domain.pfx):
# PKCS12 files, also known as PFX files, are typically used for importing and exporting certificate chains in Micrsoft IIS (Windows).
# You will be prompted for export passwords, which you may leave blank. Note that you may add a chain of certificates to the PKCS12 file by concatenating the certificates together in a single PEM file (domain.crt) in this case.
%.pfx: | %.key %.crt
	openssl pkcs12 \
	-inkey domain.key \
	-in domain.crt \
	-export -out domain.pfx

# Convert PKCS12 to PEM
# Use this command if you want to convert a PKCS12 file (domain.pfx) and convert it to PEM format (domain.combined.crt):
%.crt: | %.pfx
	openssl pkcs12 \
		-in domain.pfx \
		-nodes -out domain.combined.crt


# .PRECIOUS: ca/*
	# private/*.key.pem certs/*.cert.pem csr/*.csr.pem
# .SECONDARY: private/*.key.pem certs/*.cert.pem csr/*.csr.pem
.INTERMEDIATE: *.csr.pem
.PRECIOUS:  csr/*.csr.pem $(intermediate_csr)
