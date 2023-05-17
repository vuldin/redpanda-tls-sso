## RHEL prerequisites

`wget` is used to download the RPM packages from the releases page on Github:

```bash
sudo yum install -y wget
```

If you need to either 1) create your own self-signed certificates or 2) extract certificates from a PFX file, then you will need `openssl`:

```bash
sudo yum install -y openssl
```

You will need a Redpanda license, and this should be located at `/etc/redpanda/redpanda.license`.

## Steps

The following steps walk through installing Redpanda and Console, configuring TLS, SSO, RBAC, and starting the services. There is also an [appendix](#appendix) which covers generating self-signed TLS certificates, extracting certificates from PFX files, and configuring rpk for TLS.

### Install Redpanda

The following command will add the Redpanda repo to your rpm configuration, and then install the latest Redpanda version:

```bash
curl -1sLf 'https://dl.redpanda.com/nzc4ZYQK3WRGd9sy/redpanda/cfg/setup/bash.rpm.sh' | \
sudo -E bash && sudo yum install redpanda -y
```

Run the following commands to tune your system for production

```bash
sudo rpk redpanda mode production && \
sudo rpk redpanda tune all
```

### Install Redpanda Console

The [latest release candidate](https://github.com/redpanda-data/console/releases/tag/v2.3.0-rc1) of Redpanda Console includes TLS termination. This is required for secure connections to the Console, including when redirecting from SSO providers when single-sign-on is enabled. To install this version, download and install the latest RPM package:

```bash
wget https://github.com/redpanda-data/console/releases/download/v2.3.0-rc1/redpanda-console-2.3.0.rc1.x86_64.rpm && \
sudo rpm -i redpanda-console-2.3.0.rc1.x86_64.rpm
```

### Configure TLS

#### Redpanda

The following configuration shows TLS configured on both the Kafka and admin API ports:

```bash
redpanda:
  data_directory: /var/lib/redpanda/data
  seed_servers: []
  rpc_server:
    address: 0.0.0.0
    port: 33145
  kafka_api:
  - name: tls_listener
    address: 0.0.0.0
    port: 9092
  kafka_api_tls:
  - name: tls_listener
    key_file: /etc/redpanda/certs/node.key
    cert_file: /etc/redpanda/certs/node.crt
    truststore_file: /etc/redpanda/certs/ca.crt
    enabled: true
  admin:
  - address: 0.0.0.0
    port: 9644
  admin_api_tls:
  - key_file: /etc/redpanda//certs/node.key
    cert_file: /etc/redpanda//certs/node.crt
    truststore_file: /etc/redpanda//certs/ca.crt
    enabled: true
rpk:
  enable_usage_stats: true
  tune_network: true
  tune_disk_scheduler: true
  tune_disk_nomerges: true
  tune_disk_write_cache: true
  tune_disk_irq: true
  tune_cpu: true
  tune_aio_events: true
  tune_clocksource: true
  tune_swappiness: true
  coredump_dir: /var/lib/redpanda/coredump
  tune_ballast_file: true
pandaproxy: {}
schema_registry: {}
```

For more details, see [this Redpanda configuration file](./redpanda-config/redpanda-0/redpanda.yaml).

#### Redpanda Console

Here is an example configuration for Console, with TLS, SSO via OIDC, a license, and RBAC enabled:

```
licenseFilepath: /etc/redpanda/redpanda.license
server:
  listenPort: 8080
  # allowedOrigins: ["http://localhost:3000"]
  httpsListenPort: 443
  tls:
    enabled: true
    certFilepath: /etc/redpanda/certs/node.crt
    keyFilepath: /etc/redpanda/certs/node.key
kafka:
  brokers: "localhost:9092"
  schemaRegistry:
    enabled: true
    urls: "http://localhost:8081"
  tls:
    enabled: true
    caFilepath: "/etc/redpanda/certs/ca.crt"
    certFilepath: "/etc/redpanda/certs/node.crt"
    keyFilepath: "/etc/redpanda/certs/node.key"
    # insecureSkipTlsVerify: false
#  sasl:
#    enabled: true
#    username: admin
#    password: your_password
#    mechanism: SCRAM-SHA-512
redpanda:
  adminApi:
    enabled: true
    urls:
    - "https://localhost:9644"
    tls:
      enabled: true
      caFilepath: "/etc/redpanda/certs/ca.crt"
      certFilepath: "/etc/redpanda/certs/node.crt"
      keyFilepath: "/etc/redpanda/certs/node.key"
login:
  enabled: true
  jwtSecret: <redacted>
  useCookieChunking: true
  oidc:
    enabled: true
    clientId: <redacted>
    clientSecret: <redacted>
    issuerUrl: https://accounts.google.com
#    issuerTls:
#      caFilepath:
#      certFilepath:
#      keyFilepath:
#    userIdentifyingClaimKey: sub
enterprise:
  rbac:
    enabled: true
    roleBindingsFilepath: /etc/redpanda/role-bindings.yaml
```

An example `role-bindings.yaml` file:

```
roleBindings:
- metadata:
    name: Developers
  subjects:
  - kind: user
    provider: OIDC
    name: 100063441999230555503
  roleName: editor
```

#### Generate JWT token

You can use the following command to generate a JWT token:

```bash
LC_ALL=C tr -dc '[:alnum:]' < /dev/random | head -c32
```

Add the generated code to your config above (replace the value of `jwtSecret`).

See [this Console configuration file](./console-config/redpanda-console-config.yml) for more details.

### Start Redpanda and Console

```bash
sudo systemctl start redpanda redpanda-console
```

## Appendix

### Configure rpk for TLS

While not strictly necessary, it is recommended to save your TLS configuration that `rpk` will use into the `rpk` section of `/etc/redpanda/redpanda.yaml`. An example configuration is provided below:

```
rpk:
  kafka_api:
    brokers:
    - redpanda-0.mydomain.com:9092
    - redpanda-1.mydomain.com:9092
    - redpanda-2.mydomain.com:9092
    tls:
      cert_file: certs/node.crt
      key_file: certs/node.key
      truststore_file: certs/ca.crt
  admin_api:
    addresses:
    - redpanda-0.mydomain.com:9644
    - redpanda-1.mydomain.com:9644
    - redpanda-2.mydomain.com:9644
    tls:
      cert_file: certs/node.crt
      key_file: certs/node.key
      truststore_file: certs/ca.crt
```

Replace the broker domain names with your own, and also make sure the cert/key paths are modified for your environment. If you ran `generate-certs.sh`, then the above path is correct.

You should now be able to run the following commands, which connect `rpk` to both the Kafka and admin ports:

```bash
rpk cluster info
rpk cluster health
```

### Extract certs from PFX archive

PFX files are archives that contain one or more certificates and/or key files. In order to extract from a PFX file, you will need the export password used when creating the archive. You will be asked for this password after running each command below.

Export the private key:

```bash
openssl pkcs12 -in certname.pfx -nocerts -out key.pem -nodes
```

Export the certificate:

```bash
openssl pkcs12 -in certname.pfx -nokeys -out cert.pem
```

Remove the passphrase from the private key:

```bash
openssl rsa -in key.pem -out server.key
```

More details can be found [here](https://wiki.cac.washington.edu/display/infra/Extracting+Certificate+and+Private+Key+Files+from+a+.pfx+File) and [here](https://sslhow.com/how-to-convert-pfx-to-pem).

### Create self-signed certificates

> Skip this step if you don't need self-signed certificates, or if they are already provided for you.

Certificates are needed for TLS connections to the following:

1. Redpanda
2. Redpanda Console
3. your SSO provider

Each broker should have the same certificate so that clients can connect to any broker as needed. Redpanda Console can have its own certificate or make use of the same one used by the brokers, but it is important to ensure that `alt_names` in the certificate configuration includes a suitable DNS entry for each server that will use the certificate. One way to do this is by adding a wildcard entry:

```bash
[ alt_names ]
DNS.1 = localhost
DNS.2 = redpanda
DNS.3 = console
DNS.4 = connect
DNS.5 = "*.mydomain.com"
IP.1 = 127.0.0.1
```

The 5th DNS entry would ensure that your self-signed certificate will work for all the following names:

- `redpanda-0.mydomain.com`
- `redpanda-1.mydomain.com`
- `redpanda-2.mydomain.com`
- `redpanda-console.mydomain.com`

See [generate-certs.sh](generate-certs.sh) for details on the `openssl` commands required to generate a self-signed certificate.

The following steps assume your certificates are available in the `/certs` directory:

```bash
> ls /etc/redpanda/certs
ca.crt  ca.key  node.crt  node.key
```
