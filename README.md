# remote-workers

Remote balena builder workers and self-hosted GitHub runners for balena.io

## Supported Device Types

We are using [container contracts](https://docs.balena.io/learn/develop/container-contracts/#container-contracts) to control which services are deployed to different host architectures.

Currently only `aarch64` and `amd64` OS architectures are supported, and Supervisor v14.11.0 or later is required.
