#!/bin/bash

# Print a report of the hardware state of a ROCK 5B+ running one of these
# images: what was detected, which drivers are loaded, and the errors of the
# current boot. Run it on the board, then attach the report to an issue:
#
#   sudo bash hw-report.sh > hw-report.txt

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root" >&2
    exit 1
fi

# Keep the errors in the report, skip the loops over missing devices
exec 2>&1
shopt -s nullglob

section() {
    printf '\n===== %s =====\n' "$1"
}

# Run a command if it is installed
run() {
    if command -v "$1" > /dev/null; then
        "$@" 2>&1
    else
        echo "($1 is not installed)"
    fi
}

section "System"
grep PRETTY_NAME /etc/os-release
uname -a
tr -d '\0' < /proc/device-tree/model; echo
cat /proc/cmdline
dpkg-query -W -f '${Package} ${Version}\n' 'u-boot-*' 2> /dev/null
run systemd-analyze
systemctl --failed --no-legend

section "Boot files"
grep -E '^\s*(label|linux|initrd|fdt|fdtdir)\b' /boot/extlinux/extlinux.conf
ls -l /boot

section "CPU and memory"
lscpu | grep -E '^(Model name|CPU\(s\)|CPU max MHz|CPU min MHz):'
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    echo "$(basename "${policy}"): CPUs $(cat "${policy}/related_cpus"), governor $(cat "${policy}/scaling_governor"), current $(cat "${policy}/scaling_cur_freq") kHz, available $(cat "${policy}/scaling_available_frequencies" 2> /dev/null)"
done
free -h

section "Temperatures and cooling"
for zone in /sys/class/thermal/thermal_zone*; do
    temp="$(cat "${zone}/temp" 2> /dev/null)" && echo "$(cat "${zone}/type"): $((temp / 1000)) °C"
done
for device in /sys/class/thermal/cooling_device*; do
    echo "$(cat "${device}/type"): state $(cat "${device}/cur_state")/$(cat "${device}/max_state")"
done
for hwmon in /sys/class/hwmon/hwmon*; do
    echo "$(basename "${hwmon}"): $(cat "${hwmon}/name")"
done

section "Storage"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL
df -h /

section "PCI and USB"
run lspci -nn
run lsusb
run lsusb -t

section "Network"
ip -br link
ip -br addr
for interface in /sys/class/net/*; do
    [ -e "${interface}/device" ] || continue
    echo "$(basename "${interface}"): driver $(basename "$(readlink -f "${interface}/device/driver")"), speed $(cat "${interface}/speed" 2> /dev/null || echo "?")"
done
run iw dev
run rfkill list

section "Display, GPU, NPU and video"
for connector in /sys/class/drm/card*-*; do
    echo "$(basename "${connector}"): $(cat "${connector}/status") $(head -n 1 "${connector}/modes" 2> /dev/null)"
done
ls /dev/dri /dev/accel 2>&1
for video in /sys/class/video4linux/*; do
    echo "$(basename "${video}"): $(cat "${video}/name")"
done

section "Audio"
cat /proc/asound/cards

section "RTC and time"
for rtc in /sys/class/rtc/rtc*; do
    echo "$(basename "${rtc}"): $(cat "${rtc}/name"), $(cat "${rtc}/date" 2> /dev/null) $(cat "${rtc}/time" 2> /dev/null)"
done
run timedatectl

section "Loaded modules"
lsmod | awk 'NR > 1 { print $1 }' | sort | tr '\n' ' '
echo

section "Kernel messages of the board drivers"
dmesg | grep -i -E 'rtw89|btrtl|bluetooth|r8169|panthor|rocket|hantro|rkvdec|vdpu|rkvenc|es8316|fusb302|tcpm|hdmirx|hdptx|pcie|nvme|mmc[0-9]|hym8563|pwm-fan'

section "Kernel errors and warnings"
dmesg --level=err,warn

section "Errors of this boot"
journalctl -b -p err --no-pager | tail -n 100
