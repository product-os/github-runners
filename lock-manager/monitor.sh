#!/usr/bin/env bash

# This script is used to monitor the logs of self-hosted runners
# and create a balena supervisor update lock when runners are in use.
# https://docs.balena.io/learn/deploy/release-strategy/update-locking/

# It requires the balena engine socket, docker-cli, and the flock executable.

# Example logs we are looking for:
# 2023-11-10 15:15:07Z: Listening for Jobs
# 2023-11-10 15:17:15Z: Running job: Flowzone / Is website
# 2023-11-10 15:17:27Z: Job Flowzone / Is website completed with result: Succeeded

set -euo pipefail

lock_file=/tmp/balena/updates.lock
in_progress=false

while true; do
    for id in $(docker ps --filter "name=runner" --format "{{.ID}}"); do
        # get all recent container logs matching supported filters and sort them by timestamp
        # shellcheck disable=SC2086
        logs="$(docker logs --since 30m "${id}" | grep -E "Listening for Jobs|Running job:|completed with result:" | sort -k 1,1 || true)"

        # get the last log line (most recent) and check if it's a job start
        # if it is, then we have a running job and we should create a lock
        if echo "${logs}" | tail -n 1 | grep "Running job:" >/dev/null; then
            in_progress=true
            echo "Container ${id} is running a job."
            docker ps --filter "id=${id}" --format "{{.ID}} {{.Names}} {{.Status}}"
            echo "${logs}"
            break
        fi
    done

    if [ "${in_progress}" = true ]; then
        echo "Locking supervisor updates..."
        exec {FD}<${lock_file}
        (flock -n $FD && sleep infinity) &
    else
        rm -vf ${lock_file}
    fi

    sleep 10
done
