#!/bin/bash

KERNELS=(
    "linux:/vmlinuz-linux:/initramfs-linux.img"
    "linux-zen:/vmlinuz-linux-zen:/initramfs-linux-zen.img"
    "linux-lts:/vmlinuz-linux-lts:/initramfs-linux-lts.img"
)

KERNEL_PARAMS=(
    "loglevel=3"
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

detect_microcode() {
    if grep -q "AuthenticAMD" /proc/cpuinfo; then
        echo "amd:amd-ucode.img"
    elif grep -q "GenuineIntel" /proc/cpuinfo; then
        echo "intel:intel-ucode.img"
    else
        echo ""
    fi
}

get_root_uuid() {
    local rootdev
    rootdev=$(findmnt / -o SOURCE -n)
    ROOT_UUID=$(blkid -o value -s UUID "$rootdev")
}

get_swap_uuid() {
    local swapdev
    swapdev=$(swapon --show=NAME --noheadings || true)
    [ -n "$swapdev" ] && SWAP_UUID=$(blkid -o value -s UUID "$swapdev") || SWAP_UUID=""
}

enable_hibernation() {
    sed -i 's/HOOKS=(\(.*\) autodetect/HOOKS=(\1 resume autodetect/' /etc/mkinitcpio.conf
}

TMPDIR=$(mktemp -d)
MICROCODE_INFO=$(detect_microcode)
MICROCODE_NAME="${MICROCODE_INFO%%:*}"
MICROCODE_IMG="${MICROCODE_INFO#*:}"

# Install microcode *before* writing entry files
if [ -n "$MICROCODE_NAME" ]; then
    pacman -S "${MICROCODE_NAME}-ucode" --needed --noconfirm >/dev/null 2>&1
fi

get_root_uuid
get_swap_uuid

PARAM_STR="${KERNEL_PARAMS[*]}"

if [ ! -d "/boot/loader" ]; then
    sudo bootctl install
fi

echo "timeout 0" | tee /boot/loader/loader.conf >/dev/null
echo "default linux-zen.conf" | tee -a /boot/loader/loader.conf >/dev/null

for entry in "${KERNELS[@]}"; do
    IFS=":" read -r name kernel img <<< "$entry"

    OUT="$TMPDIR/${name}.conf"

    {
        echo "title Arch Linux ($name)"
        echo "linux $kernel"

        [ -n "$MICROCODE_IMG" ] && echo "initrd /$MICROCODE_IMG"
        echo "initrd $img"

        if [ -n "${SWAP_UUID:-}" ]; then
            enable_hibernation
            echo "options root=UUID=$ROOT_UUID resume=UUID=$SWAP_UUID rw $PARAM_STR"
        else
            echo "options root=UUID=$ROOT_UUID rw $PARAM_STR"
        fi
    } > "$OUT"
done

cp "$TMPDIR"/*.conf /boot/loader/entries/
rm -rf "$TMPDIR"

# Fix boot partition permissions & random seed file permissions
chmod 700 /boot
chmod 600 /boot/loader/random-seed

echo "✔ Boot entries generated successfully."
