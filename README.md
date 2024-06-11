# github-runners

balena deployment of self-hosted GitHub runners

Runners are deployed in two variants, `vm` and `container`, where `vm` is isolated and
safe to use on public repositories.

See [github-runner-vm](https://github.com/product-os/github-runner-vm) and [self-hosted-runners](https://github.com/product-os/self-hosted-runners) for image sources.

## VM Runner Sizes

Firecracker allows overprovisioning or oversubscribing of both CPU and memory resources for virtual machines (VMs) running on a host.
This means that the total vCPUs and memory allocated to the VMs can exceed the actual physical CPU cores and memory available on the host machine.

In order to make the most efficient use of host resources, we want to slightly overprovision the host hardware
so if/when all allocated resources are consumed by jobs (e.g. yocto) there would be minimal overlap that could lead to performance degredation.

We can use environment variables on the VM runners to automatically assign a fraction of the host resources to each VM.

So for 10 VMs in the compose stack, we could set `CPU_PERCENT=0.10` and `MEMORY_PERCENT=0.10` so each runner gets 1/10th of total resources.
Note that these shares are rounded up to the nearest power of 2 so they are already higher than the fraction provided.

See the [github-runner-vm](https://github.com/product-os/github-runner-vm) README for more.
