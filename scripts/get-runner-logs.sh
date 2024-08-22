#!/usr/bin/env bash

# Identify which balena host is running a specific container ID
# via journal logs on the device.
# Usage: ./where-is-runner.sh <container_id>

container_id="${1}"

# Hardcoded list of UUIDs from both runner fleets
# https://dashboard.balena-cloud.com/fleets/2123949
# balena devices -f product_os/github-runners-amd64 -j | jq -r '.[].uuid'
# https://dashboard.balena-cloud.com/fleets/2123948
# balena devices -f product_os/github-runners-aarch64 -j | jq -r '.[].uuid'
balena_hosts="
f8732db12e3776815b7cf1c1b2328240
b7ed9167d21da71f4a30be249a430ef7
1645441a8527d465119e8385ce979b7f
dd58519544d0a6fd33012ae98f9d7e96
47500e503ae823835690e1909a58729e
c821339756472d1801e5f2805b7b8503
03b8f23d06a9fa301e978ff6567df36f
0f65b15498faee0a1e0aa2204b618c2f
e8ba3110cdbdafc07a209abdae4bd950
97618ca8cee58bf948f5c07e80bef02b
9ffb67713603011ce864cc0884387072
6f9556dd1f7a445c588a1f8035bdafe6
"

for host in ${balena_hosts}; do
    echo "Connecting to host: ${host}"
    echo "journalctl -u balena | grep '${container_id}' ; exit" | balena ssh "${host}"
done
