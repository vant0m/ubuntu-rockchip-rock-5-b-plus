# shellcheck shell=bash

export BOARD_NAME="Radxa ROCK 5B Plus"
export BOARD_MAKER="Radxa"
export BOARD_SOC="Rockchip RK3588"
export BOARD_CPU="ARM Cortex A76 / A55"
export COMPATIBLE_SUITES=("jammy" "noble" "resolute" "stonking")
export COMPATIBLE_FLAVORS=("server" "server-diet" "desktop")

# Suites using the kernel from the Ubuntu archive boot with mainline U-Boot
if [[ ${KERNEL_TYPE} == "mainline" ]]; then
    export UBOOT_PACKAGE="u-boot-mainline-rk3588"
    export UBOOT_RULES_TARGET="rock5b-rk3588"
else
    export UBOOT_PACKAGE="u-boot-radxa-rk3588"
    export UBOOT_RULES_TARGET="rock-5b-plus-rk3588"
fi

function config_image_hook__rock-5b-plus() {
    local rootfs="$1"
    local overlay="$2"
    local suite="$3"

    # Installer to the eMMC or an NVMe drive, run by hand or on the first
    # boot when asked on the CIDATA partition. flashcp writes the SPI flash
    chroot "${rootfs}" apt-get -y install rsync mtd-utils
    install -m 755 "${overlay}/usr/sbin/ubuntu-rockchip-install" "${rootfs}/usr/sbin/ubuntu-rockchip-install"
    ln -sf ubuntu-rockchip-install "${rootfs}/usr/sbin/install-to-emmc"
    ln -sf ubuntu-rockchip-install "${rootfs}/usr/sbin/install-to-nvme"
    cp "${overlay}/usr/lib/systemd/system/ubuntu-rockchip-auto-install.service" "${rootfs}/usr/lib/systemd/system/"
    chroot "${rootfs}" systemctl enable ubuntu-rockchip-auto-install

    if [ "${suite}" == "jammy" ] || [ "${suite}" == "noble" ]; then
        # Install panfork
        chroot "${rootfs}" add-apt-repository -y ppa:jjriek/panfork-mesa
        chroot "${rootfs}" apt-get update
        chroot "${rootfs}" apt-get -y install mali-g610-firmware
        chroot "${rootfs}" apt-get -y dist-upgrade

        # Install libmali blobs alongside panfork
        chroot "${rootfs}" apt-get -y install libmali-g610-x11

        # Install the rockchip camera engine
        chroot "${rootfs}" apt-get -y install camera-engine-rkaiq-rk3588

        # Fix Bluetooth not working with the onboard RTL8852BE WiFi + BT chip
        cp "${overlay}/usr/lib/systemd/system/radxa-a8-bluetooth.service" "${rootfs}/usr/lib/systemd/system/radxa-a8-bluetooth.service"
        chroot "${rootfs}" systemctl enable radxa-a8-bluetooth

        # Fix and configure audio device
        mkdir -p "${rootfs}/usr/lib/scripts"
        cp "${overlay}/usr/lib/scripts/alsa-audio-config" "${rootfs}/usr/lib/scripts/alsa-audio-config"
        cp "${overlay}/usr/lib/systemd/system/alsa-audio-config.service" "${rootfs}/usr/lib/systemd/system/alsa-audio-config.service"
        chroot "${rootfs}" systemctl enable alsa-audio-config
    fi

    if [[ ${KERNEL_TYPE} == "mainline" ]]; then
        # Mainline U-Boot detects the board and sets fdtfile on its own, but
        # point extlinux at the ROCK 5B+ device tree shipped with the Ubuntu
        # kernel anyway so a failed detection cannot boot the ROCK 5B one
        mkdir -p "${rootfs}/etc/u-boot-menu/conf.d"
        echo 'U_BOOT_FDT="device-tree/rockchip/rk3588-rock-5b-plus.dtb"' > "${rootfs}/etc/u-boot-menu/conf.d/rock-5b-plus.conf"

        # The device tree gives the blue status LED the heartbeat trigger,
        # but the trigger is a module without alias that nothing loads: the
        # LED would just turn off once Linux runs instead of blinking
        mkdir -p "${rootfs}/etc/modules-load.d"
        echo "ledtrig-heartbeat" > "${rootfs}/etc/modules-load.d/rock-5b-plus.conf"

        # Tyr, the experimental Rust driver for the Mali GPU, matches the same
        # device as Panthor. Whichever probes first gets the GPU, and Mesa
        # only works with Panthor
        mkdir -p "${rootfs}/etc/modprobe.d"
        echo "blacklist tyr" > "${rootfs}/etc/modprobe.d/rock-5b-plus.conf"

        # Keep the clock across reboots, the images use chrony and not
        # systemd-timesyncd, which would do it
        cp "${overlay}/usr/lib/systemd/system/ubuntu-rockchip-save-clock.service" "${rootfs}/usr/lib/systemd/system/"
        chroot "${rootfs}" systemctl enable ubuntu-rockchip-save-clock

        # The Ubuntu generic kernel is an EFI application that the booti
        # command of U-Boot refuses. Wrap u-boot-update so the raw kernel
        # Image is extracted and used by extlinux, including for kernels
        # installed later by apt.
        install -D -m 755 "${overlay}/usr/lib/ubuntu-rockchip/kernel-image" "${rootfs}/usr/lib/ubuntu-rockchip/kernel-image"
        install -D -m 755 "${overlay}/usr/lib/ubuntu-rockchip/u-boot-update" "${rootfs}/usr/lib/ubuntu-rockchip/u-boot-update"
        chroot "${rootfs}" dpkg-divert --local --rename --divert /usr/sbin/u-boot-update.distrib --add /usr/sbin/u-boot-update
        ln -sf /usr/lib/ubuntu-rockchip/u-boot-update "${rootfs}/usr/sbin/u-boot-update"
        chroot "${rootfs}" u-boot-update
    fi

    return 0
}
