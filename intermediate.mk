SHELL = /bin/bash

export C ?= UK
export ST ?= Left
export L ?= Earth
export O ?= Wrrr Right OGgg
export OU ?= $(strip $(shell basename $(CURDIR)))

openssl.cnf := openssl.cnf
certificates := $(wildcard **/*.cert.pem)

ca_name ?= CA_intermediate
extensions ?= client_cert

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Root & Intermediate certificates  - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
ca.cert.pem : ca_name := CA_default
ca.cert.pem : extensions += root_ca
intermediate.csr.pem : extensions := intermediate_ca

# To create a certificate, use the intermediate CA to sign the CSR.
# If the certificate is going to be used on a server, use the server_cert extension.
# If the certificate is going to be used for user authentication, use the usr_cert extension.
%.email.cert.pem : extensions += email_cert
%.srv.cert.pem : extensions += server_cert

# Create a key and certificate signing request (CSR) in one command
# openssl genrsa -nodes -aes256 -out private/${KEY_FQDN}.key.pem 2048
# -keyout instead of -key allows create key and csr in one command,
# together with -nodes password can be ommited
.DEFAULT_GOAL := intermediate.csr.pem

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Server & clients certificates - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
.PRECIOUS: %.cnf
%.cnf:
	mkdir -p $(@D)
	cp --force $(openssl.cnf) $@
	$(call req_dist_name,$*)
	$(if $(strip $(SAN)),$(call subjectAltName,$*))


# certificate signing request (CSR)
.PRECIOUS: %.pem
%.csr.pem %.key.pem: | %.cnf
	openssl req -nodes -new -sha256 -batch \
		-config $*.cnf \
		$(addprefix -reqexts , $(reqexts)) \
		$(addprefix -extensions , $(extensions) $(if $(strip $(SAN)),SAN)) \
		-keyout $*.key.pem \
		-out $*.csr.pem
	# chmod 644 $*.key.pem


# Create certificate & Sign CSR
%.cert.pem: | %.csr.pem
	openssl ca -batch -days 375 -notext -md sha256 \
		-config $*.cnf \
		-name $(ca_name) \
		$(addprefix -extensions ,$(extensions) $(if $(strip $(SAN)),SAN)) \
		-in $*.csr.pem \
		-out $@
	# chmod 644 $@


# Combine private key ad certificate
%.chain.pem: | intermediate.chain.pem
	cat intermediate.chain.pem $*.cert.pem > $@
	# chmod 644 $@


# Create the certificate chain file
intermediate.chain.pem: | intermediate.cert.pem
	cd .. && $(MAKE) $(shell basename $(CURDIR))/$@


# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Validate input data ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
ifndef C
$(error Undefined Country Name - C)
endif

ifndef ST
$(error Undefined State - ST)
endif

ifndef L
$(error Undefined Locality Name [city] - L)
endif

ifndef O
$(error Undefined Organization Name - O)
endif

ifndef OU
$(error Undefined Organizational Unit Name - OU)
endif

ifdef EMAIL
emailAddress += emailAddress=$(shell echo $(EMAIL) | sed 's/\(.*\)@.*/\1/')@$(CN)
endif

SAN += $(if $(IP),$(shell printf 'IP:%s\n' $(IP)))
SAN += $(if $(DNS),$(shell printf 'DNS:%s\n' $(DNS)))
SAN += $(if $(EMAIL),$(shell printf 'email:%s\n' $(EMAIL)))

define req_dist_name =
	{ echo && echo [ req_dist_name ]; \
		echo C	= 	$(C); \
		echo ST	= 	$(ST); \
		echo L	= 	$(L); \
		echo O	= 	$(O); \
		echo OU	= 	$(OU); \
		echo CN	= 	$(if $(CN),$(CN),$(shell basename $(1))); \
		echo $(emailAddress); \
	} >> $*.cnf;
endef

define subjectAltName =
	{ echo && echo [SAN]; \
		echo "subjectAltName=$$(printf '%s\n' $(SAN) | paste -sd',')"; \
	} >> $*.cnf;
endef

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Print && verify certificate ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

# Print the certificate in text form && verify
$(certificates): force intermediate.chain.pem
	openssl x509 -noout -text -in $@
	openssl verify -CAfile intermediate.chain.pem $@
	@if [[ -n "$(DNS)" ]]; then $(call verify_hostname, $(DNS)); fi
	@if [[ -n "$(IP)" ]]; then $(call verify_ip, $(IP)); fi
	@if [[ -n "$(EMAIL)" ]]; then $(call verify_email, $(EMAIL)); fi

define verify_hostname =
	openssl x509 -noout -text -in $@ | grep DNS >/dev/null && echo verifying DNS: $(1) || return 0; \
	openssl verify -CAfile intermediate.chain.pem -verify_hostname $(1) $@
endef

define verify_ip =
	openssl x509 -noout -text -in $@ | grep IP >/dev/null && echo verifying IP: $(1) || return 0; \
	openssl verify -CAfile intermediate.chain.pem -verify_ip $(1) $@
endef

define verify_email =
	openssl x509 -noout -text -in $@ | grep emailAddress >/dev/null && echo verifying email: $(1) || return 0; \
	openssl verify -CAfile intermediate.chain.pem -verify_email $(1) $@
endef

force: ;

define verify_server =
	openssl s_client -CAfile intermediate.chain.pem -connect fred.wrrr.gmbh:16514
endef

define subject =
	"$(shell printf '/%s' "C=$(C)" "ST=$(ST)" "L=$(L)" "O=$(O)" "OU=$(OU)" "CN=$(if $(CN),$(CN),$(shell basename $(1)))" $(emailAddress))"
endef
