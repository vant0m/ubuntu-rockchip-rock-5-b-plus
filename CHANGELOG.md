# Changelog

All notable changes to this project are listed in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- A changelog, a logo, and a README built on a common template.

### Changed

- The 26.04 images follow the hardware enablement (HWE) kernel
  (`linux-generic-hwe-26.04`). It is the same 7.0 kernel as before for now,
  and moves to 7.3 through `apt` once Canonical publishes it for 26.04. The
  26.10 images already run 7.3.

### Fixed

- Kernel updates no longer fail: `flash-kernel`, `piboot-try` and GRUB are
  pinned so that `apt` never installs them back with a new kernel. Installed
  v1.1.0 systems need the fix by hand, see
  [the README](README.md#kernel-updates-on-v110).

## [1.1.0] — 2026-10-16

### Added

- Installer to the eMMC, an NVMe drive or another disk, by hand
  (`install-to-emmc`, `install-to-nvme`, `ubuntu-rockchip-install`) or on the
  first boot of the server images, with a file on their `CIDATA` partition.
- `server-diet` flavor for 26.04 and 26.10: the server image without what a
  headless server does not need.
- `scripts/hw-report.sh`, a hardware report to attach to issues.

### Changed

- The server images boot to `multi-user.target`, and `server-diet` disables
  cloud-init once the first boot setup is done.
- The clock of 26.04 and 26.10 starts at the time of the last shutdown, or of
  the image build on the first boot.
- The desktop images are marked as beta.

### Fixed

- 26.04 and 26.10 boot: U-Boot cannot start the EFI kernels of Ubuntu, so the
  raw kernel image is extracted for it, including for the kernels installed
  later by `apt`.
- A reinstalled kernel of the same version is extracted again for U-Boot.
- The blue status LED blinks once Linux runs on 26.04 and 26.10.
- Tyr, the experimental Rust GPU driver, is blacklisted: it competed with
  Panthor for the GPU.

## 1.0.0 — 2026-10

First images of the fork. The 26.04 image did not boot, fixed in 1.1.0; the
tag is no longer available.

### Added

- Ubuntu 26.04 LTS and 26.10 images, built from the Ubuntu archive and
  mainline U-Boot v2026.10.
- GitHub Actions workflows that build the images and publish the releases.

### Changed

- The 22.04 and 24.04 images install the kernel headers, and build each kernel
  on a matching Ubuntu release.

### Removed

- Everything that does not concern the ROCK 5B+: about thirty other boards,
  their U-Boot packages, and the 24.10 and 25.04 suites.

### Fixed

- Bluetooth of the onboard RTL8852BE on 22.04 and 24.04.

[Unreleased]: https://github.com/vant0m/ubuntu-rockchip-rock-5-b-plus/compare/v1.1.0...main
[1.1.0]: https://github.com/vant0m/ubuntu-rockchip-rock-5-b-plus/releases/tag/v1.1.0
