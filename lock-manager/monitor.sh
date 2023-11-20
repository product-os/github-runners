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

LOCKFILE=/tmp/balena/updates.lock

# Create the lockfile
touch $LOCKFILE

# get all recent container logs matching supported filters and sort them by timestamp
get_sorted_logs() {
    # shellcheck disable=SC2086
    docker logs --since 30m "${1}" | grep -E "Listening for Jobs|Running job:|completed with result:" | sort -k 1,1 || true
}

are_jobs_in_progress() {
    # iterate over all runner container ids
    for id in $(docker ps --filter "name=runner" --format "{{.ID}}"); do
        # get the last log line (most recent) and check if it's a job start
        if get_sorted_logs "${id}" | tail -n 1 | grep "Running job:" >/dev/null; then
            echo "Container ${id} has a job in progress..."
            return 0
        fi
    done
    return 1
}

while true; do
    # if the subshell exits for any reason, the lock will be released automatically
    # this includes failing to get a lock, or exiting the script
    (
        # if there are any jobs in progress, create a lock
        while are_jobs_in_progress; do

            # Create a file descriptor over the given lockfile.
            exec {fd}<>${LOCKFILE}

            # request an exclusive lock in non-blocking mode (i.e. fail immediately if lock is held)
            flock -n $fd || {
                # echo "Failed to obtain update lock..."
                exit 0
            }

            # wait 10 seconds before checking container logs again
            # updates are locked during this time
            sleep 10
        done
    ) &

    # wait 10 seconds before checking container logs again
    # updates are unlocked during this time
    sleep 10
done
