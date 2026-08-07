#!/bin/bash

KERNELS=(
"linux:/vmlinuz-linux:/initramfs-linux.img"
"linux-zen:/vmlinuz-linux-zen:/initramfs-linux-zen.img"
"linux-lts:/vmlinuz-linux-lts:/initramfs-linux-lts.img"
)

KERNEL_PARAMS=(
"loglevel=3"
"apparmor=1"
"security=apparmor"
"debugfs=off"
"vsyscall=none"
"processor.ignore_ppc=1"
"split_lock_detect=off"
"libahci.ignore_sss=1"
"rootflags=noatime"
"usbcore.autosuspend=-1"
"rfkill.default_state=1"
"rfkill.master_switch_mode=2"
"amdgpu.msi=1"
"nvidia.NVreg_EnableMSI=1"
"nowatchdog"
"nmi_watchdog=0"
"module_blacklist=iTCO_wdt"
"amdgpu.audio=0"
"amdgpu.ppfeaturemask=0xffffffff"
)

MICROCODE_IMG=""

if grep -q AuthenticAMD /proc/cpuinfo; then
    pacman -S amd-ucode --needed --noconfirm
    MICROCODE_IMG="amd-ucode.img"
elif grep -q GenuineIntel /proc/cpuinfo; then
    pacman -S intel-ucode --needed --noconfirm
    MICROCODE_IMG="intel-ucode.img"
fi

ROOT_UUID=$(blkid -o value -s UUID "$(findmnt / -o SOURCE -n)")
SWAP_UUID=$(blkid -o value -s UUID "$(swapon --show=NAME --noheadings)" 2>/dev/null || true)

if [ -n "$SWAP_UUID" ]; then
    sed -i 's/\(HOOKS=.*\)block/\1resume block/' /etc/mkinitcpio.conf
fi

PARAM_STR="${KERNEL_PARAMS[*]}"

bootctl install

cat >/boot/loader/loader.conf <<EOF
timeout 0
default linux-zen.conf
EOF

mkdir -p /boot/loader/entries

for e in "${KERNELS[@]}"; do
    IFS=: read -r name kernel img <<< "$e"

    {
        echo "title Arch Linux ($name)"
        echo "linux $kernel"
        [ -n "$MICROCODE_IMG" ] && echo "initrd /$MICROCODE_IMG"
        echo "initrd $img"

        if [ -n "$SWAP_UUID" ]; then
            echo "options root=UUID=$ROOT_UUID resume=UUID=$SWAP_UUID rw $PARAM_STR"
        else
            echo "options root=UUID=$ROOT_UUID rw $PARAM_STR"
        fi
    } >/boot/loader/entries/$name.conf
done

chmod 700 /boot
[ -f /boot/loader/random-seed ] && chmod 600 /boot/loader/random-seed

mkinitcpio -P

echo "✔ Done."
