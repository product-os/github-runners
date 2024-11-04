# github-runners

balena deployment of self-hosted GitHub runners

Runners are deployed in two variants, `vm` and `container`, where `vm` is isolated and safe to use on public repositories.

See [github-runner-vm](https://github.com/product-os/github-runner-vm) and [self-hosted-runners](https://github.com/product-os/self-hosted-runners) for image sources.

## VM Runner Sizes

Firecracker allows overprovisioning or oversubscribing of both CPU and memory resources for virtual machines (VMs) running on a host.
This means that the total vCPUs and memory allocated to the VMs can exceed the actual physical CPU cores and memory available on the host machine.

In order to make the most efficient use of host resources, we want to slightly underprovision the host hardware
so if/when all allocated resources are consumed by jobs (e.g. yocto) there should be no overlap that could lead to performance degredation.

See the [github-runner-vm](https://github.com/product-os/github-runner-vm) README for more.

## Provision New Hardware

### Hetzner

> balenaOS can be deployed into [Hetzner Robot](https://robot.your-server.de/server)

1. [Order](https://robot.your-server.de/order) a suitable machine in an `ES rack` (remote power controls)
2. Download balenaOS production image from the target balenaCloud fleet:
   - x64: <https://dashboard.balena-cloud.com/fleets/2123949>
   - ARM64: <https://dashboard.balena-cloud.com/fleets/2123948>
3. For x64 only: [Unwrap](https://github.com/balena-os/balena-image-flasher-unwrap) the image
4. Copy unwrapped image to S3 playground bucket and make public

   ```shell
   aws s3 cp balena.img s3://{{bucket}}/ --acl public-read
   ```

5. Activate Hetzner Rescue system
6. Reboot or reset server

#### Single drive

> [!NOTE] This leaves the second block device unpaired and empty

1. Download and uncompress unwrapped balenaOS image to `/tmp` using `wget`
2. (Optional) Zero out target disk(s)

   ```shell
   for device in nvme{0,1}n1; do
       blkdiscard /dev/${device} -f
   done
   ```

3. Download image from S3 via wget (URL is in S3 dashboard)

4. Write image to disk (Check `lsblk` output for block device)

   ```shell
   dd if=balena.img of=/dev/nvme1n1 bs=$(blockdev --getbsz /dev/nvme1n1)
   ```

5. Reboot
6. Manually power cycle again via the Robot dashboard to work around [this issue](https://balena.fibery.io/Inputs/Pattern/Generic-x86_64-GPT-with-sw-RAID1-does-not-come-up-after-initial-flash-without-additional-power-cycle-4510)

#### Two drives via RAID1

> [!NOTE] Use `generic-amd64` or `generic-aarch64` balenaOS device type

1. Follow RAID1 setup steps [here](https://github.com/balena-os/meta-balena/blob/master/docs/raid.md)
2. Download image from S3 via wget (URL is in S3 dashboard)
3. Write image to RAID array

   ```shell
   dd if=balena.img of=/dev/md/balena bs=4096
   ```

4. Monitor synchronization progress

   ```shell
   watch cat /proc/mdstat
   ```

5. Reboot when 100% synchronized
6. Manually power cycle again via the Robot dashboard to work around [this issue](https://balena.fibery.io/Inputs/Pattern/Generic-x86_64-GPT-with-sw-RAID1-does-not-come-up-after-initial-flash-without-additional-power-cycle-4510)
