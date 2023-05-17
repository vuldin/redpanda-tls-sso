## Docker prerequisites

- A Redpanda license is needed within Console to make use of SSO and RBAC. If using the Docker compose file, you can copy your `redpanda.license` file to the `./license` folder, which will be mounted and used automatically.
- Docker is needed if you want to use the provided `docker-compose.yaml` file
- The `openssl` CLI is needed if you must create self-signed certificates/keys, or if you need to convert a PFX archive to individual certificate files. The easiest way to install is through your Linux system's built-in package manager

## Steps

### Reset

If you have previously followed these steps, then delete any old certs:

Reset ownership, delete Redpanda data, restore config files in this directory:

```
./reset.sh
```


```
./delete-certs.sh
```


### Create self-signed certificates

Generate new certs:

```
./generate-certs.sh
```

Save this sample `rpk` config to `/etc/redpanda/redpanda.yaml`:

```
rpk:
  kafka_api:
    brokers:
    - localhost:9092
    - localhost:9192
    - localhost:9292
    tls:
      cert_file: certs/node.crt
      key_file: certs/node.key
      truststore_file: certs/ca.crt
  admin_api:
    addresses:
    - localhost:9644
    - localhost:9744
    - localhost:9844
    tls:
      cert_file: certs/node.crt
      key_file: certs/node.key
      truststore_file: certs/ca.crt

```

Start the cluster:

```
docker compose up
```

`rpk` should now be able to connect to the external kafka and admin listeners via TLS:

```
rpk cluster info
rpk cluster health
```

Create a sample topic across all brokers:

```
rpk topic create continents -p 3
```

HTTP proxy has clients that connect to both the internal and external kafka listeners. But sending a request to the listener at port 8082 (that is connecting to the external kafka listener) doesn't make use of TLS:

```
curl -s \
  -X POST "http://localhost:8082/topics/continents" \
  -H "Content-Type: application/vnd.kafka.json.v2+json" \
  -d '{"records":[{"key": "from-proxy","value":"North America"}]}'
```

Consume the data created by the above command:

```
rpk topic consume continents
```
