# Target platforms supported by u-boot.
# debian/rules includes this Makefile snippet.

# Mainline U-Boot detects the ROCK 5B, ROCK 5B+ and ROCK 5T at runtime and
# picks the matching device tree, so one build covers all three boards.
u-boot-rockchip_platforms += rock5b-rk3588
rock5b-rk3588_ddr := rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.24.bin
rock5b-rk3588_bl31 := rk3588_bl31_v1.56.elf
rock5b-rk3588_pkg := rock-5b-plus
