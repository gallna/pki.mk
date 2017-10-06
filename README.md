# Usage

```bash
# bob.wrrr.gmbh
# fred.wrrr.gmbh
# zych.wrrr.gmbh

make bob/intermediate.cert.pem && cd bob

# server certificate
KEY_CN=fred.wrrr.gmbh SAN_DNS=fred SAN_IP=10.15.15.5 make fred/server.srv.cert.pem
# client certificate
KEY_CN=fred SAN_DNS=fred.wrrr.gmbh SAN_IP=10.15.15.5 make fred/client.cert.pem
# client email certificate
KEY_CN=fred KEY_EMAIL=fred@fred.wrrr.gmbh make fred/fred.email.cert.pem
```

```bash
make zed/intermediate.cert.pem && make zed/intermediate.chain.pem && cd zed
KEY_CN=fred.wrrr.gmbh SAN_DNS=fred SAN_IP=10.15.15.5 make fred/server.srv.cert.pem; \
KEY_CN=fred SAN_DNS=fred.wrrr.gmbh SAN_IP=10.15.15.5 make fred/client.cert.pem; \
KEY_CN=fred KEY_EMAIL=fred@fred.wrrr.gmbh make fred/fred.email.cert.pem; \
KEY_CN=tomasz.wrrr.gmbh SAN_DNS=tomasz SAN_IP=10.15.15.5 make tomasz/server.srv.cert.pem; \
KEY_CN=tomasz SAN_DNS=tomasz.wrrr.gmbh SAN_IP=10.15.15.5 make tomasz/client.cert.pem; \
KEY_CN=tomasz.wrrr.gmbh KEY_EMAIL=tomasz@tomasz.wrrr.gmbh make tomasz/client.email.cert.pem
```

```bash
make zed/intermediate.cert.pem && make zed/intermediate.chain.pem && cd zed
DNS="fred.wrrr.gmbh fred.balakala" IP="10.15.15.5 10.10.10.15" make fred/fred.srv.cert.pem;
DNS="tomasz.wrrr.gmbh tomasz.balakala" IP="10.15.15.5 10.10.10.10" make tomasz/tomasz.srv.cert.pem;

EMAIL=fred@fred.wrrr.gmbh make fred.wrrr.gmbh/fred.email.cert.pem;
EMAIL=tomasz@tomasz.wrrr.gmbh make tomasz/client.email.cert.pem
```


```bash
$ EMAIL=a@b.c CN=jab.baj DNS="a.b.c z.x.c" IP=11.22.33.44 make abuba.com/https$((i++)).srv.cert.pem
$ EMAIL=a@b.c DNS=a.b.c IP=11.22.33.44 make abuba.com/https97.srv.cert.pem

> openssl verify -CAfile intermediate.chain.pem abuba.com/https97.srv.cert.pem
> abuba.com/https97.srv.cert.pem: OK
> verifying DNS: a.b.c
> abuba.com/https97.srv.cert.pem: OK
> verifying IP: 11.22.33.44
> abuba.com/https97.srv.cert.pem: OK
> verifying email: a@b.c
> abuba.com/https97.srv.cert.pem: OK
```
