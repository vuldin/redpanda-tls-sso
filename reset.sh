#!/bin/bash
mkdir -p redpanda-data/{redpanda-0,redpanda-1,redpanda-2}
mkdir -p redpanda-config/{redpanda-0,redpanda-1,redpanda-2}/certs
sudo chown -R $(whoami):$(whoami) {redpanda-data,redpanda-config}
sudo rm -r redpanda-data/redpanda-0/* 2> /dev/null
sudo rm -r redpanda-data/redpanda-1/* 2> /dev/null
sudo rm -r redpanda-data/redpanda-2/* 2> /dev/null
#git restore -- . && git clean -df
sudo chown -R 101:101 redpanda-data
sudo chown -R 101:101 redpanda-config/{redpanda-0,redpanda-1,redpanda-2}

