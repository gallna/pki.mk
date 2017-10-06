SHELL = /bin/bash

# Root certificate
%/ca.cert.pem : OU := Root CA
%/ca.cert.pem : CN := Certificate-Authority

export C ?= UK
export ST ?= Left
export L ?= Earth
export O ?= Wrrr GmbH
export CN ?= Intermediate-Authority
export SAN :=

ca := .ca
openssl.cnf := openssl.cnf
intermediate.mk := $(CURDIR)/intermediate.mk

certs.intermediate := $(wildcard */*.cert.pem)
certs := $(wildcard **/**/*.cert.pem)

.DEFAULT_GOAL := info
.PRECIOUS: %.pem

%: ; mkdir -p $@ && $(MAKE) $@/Makefile $@/crlnumber $@/serial $@/index.txt
%/Makefile: ; mkdir -p $* && ln -s $(intermediate.mk) $(abspath $@)
%/index.txt: ; mkdir -p $* && touch $@ && touch $@.attr
%/serial: ; mkdir -p $* && echo 1000 > $@
%/crlnumber: ; mkdir -p $* && echo 1000 > $@

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - CA root certificate ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

# Create the root key and certificate
$(ca)/ca.cert.pem: | $(ca)
	openssl req -nodes -new -x509 -days 7300 -sha256 \
		-config $(openssl.cnf) \
		-extensions root_ca \
		-keyout $(@D)/ca.key.pem \
		-out $@
	# chmod 644 $(@D)/ca.key.pem
	# chmod 644 $@

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Intermediate certificate - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
.PRECIOUS: %/openssl.cnf
%/openssl.cnf:
	$(MAKE) $(@D) && cp $(openssl.cnf) $@ && cd $(@D) && $(MAKE)


# Create the intermediate certificate
.PRECIOUS: %/intermediate.csr.pem
%/intermediate.csr.pem %/intermediate.key.pem: %/openssl.cnf | $(ca)/ca.cert.pem
	cd $(@D) && $(MAKE) $(@F)


# Create the intermediate certificate
%/intermediate.cert.pem: | %/intermediate.csr.pem
	openssl ca -days 365 -md sha256 -batch -notext \
		-config $(openssl.cnf) \
		-in $(@D)/intermediate.csr.pem \
		-out $@ \
		-extensions intermediate_ca
	# chmod 644 $@


# Create the certificate chain file
%/intermediate.chain.pem: | %/intermediate.cert.pem
	cat $(ca)/ca.cert.pem $| > $(@)
	# chmod 644 $(@)

# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - Print && verify certificate ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~
# ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~ - ~

$(certs.intermediate): force
	openssl x509 -noout -text -in $@
	openssl verify -CAfile $(ca)/ca.cert.pem $@

# Print the certificate in text form && verify
$(certs): force
	openssl x509 -noout -text -in $@
	openssl verify -CAfile $(dir $(@D))intermediate.chain.pem $@

clean:
	rm -rf $(dir $(certs.intermediate)) .ca $$(echo */)

force: ;
