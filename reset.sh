#!/bin/bash
mkdir -p {redpanda-config,redpanda-data}/{redpanda-0,redpanda-1,redpanda-2}
sudo chown -R $(whoami):$(whoami) {redpanda-data,redpanda-config}
sudo rm -r redpanda-data/redpanda-0/* 2> /dev/null
sudo rm -r redpanda-data/redpanda-1/* 2> /dev/null
sudo rm -r redpanda-data/redpanda-2/* 2> /dev/null
#git restore -- .
sudo chown -R 101:101 {redpanda-data,redpanda-config}

