#!/usr/bin/env bash
# Apply kernel parameters via rpm-ostree

set -euo pipefail

KERNEL_PARAMS=(
    "loglevel=3"
    "audit=0"
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

# ── Helpers ────────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Pre-flight ─────────────────────────────────────────────────────────────────

if ! command -v rpm-ostree &>/dev/null; then
    error "rpm-ostree not found. Is this an immutable (Bazzite/Silverblue) system?"
    exit 1
fi

# Get currently active kernel args
CURRENT_KARGS=$(rpm-ostree kargs 2>/dev/null || true)
info "Fetched current kernel args."
echo

# ── Build --append list (skip already-present params) ─────────────────────────

APPENDS=()
SKIPPED=()

for param in "${KERNEL_PARAMS[@]}"; do
    # Extract just the key (before '=') for a loose match, handles flags like "nowatchdog"
    key="${param%%=*}"
    if echo "$CURRENT_KARGS" | grep -qw "$key"; then
        SKIPPED+=("$param")
    else
        APPENDS+=("--append=$param")
    fi
done

# ── Report skipped ─────────────────────────────────────────────────────────────

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    warn "Already present (skipping):"
    for p in "${SKIPPED[@]}"; do
        echo "       • $p"
    done
    echo
fi

# ── Apply ──────────────────────────────────────────────────────────────────────

if [[ ${#APPENDS[@]} -eq 0 ]]; then
    success "All kernel parameters are already set. Nothing to do."
    echo
    exit 0
fi

info "Applying ${#APPENDS[@]} kernel parameter(s):"
for a in "${APPENDS[@]}"; do
    echo "       • ${a#--append=}"
done
echo

if rpm-ostree kargs "${APPENDS[@]}"; then
    echo
    success "Kernel parameters staged successfully."
    echo
    echo -e "  ${YELLOW}Reboot to activate:${NC}  systemctl reboot"
    echo
else
    error "rpm-ostree kargs failed. Check the output above."
    exit 1
fi
