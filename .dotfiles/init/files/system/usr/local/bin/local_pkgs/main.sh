#!/usr/bin/env bash
set -euo pipefail

BUILD_USER="buildpkg"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/pkgs"
FAILED_PACKAGES=()  # Track failed packages

log() {
    local level="$1"
    shift
    if [[ "$level" == "DEBUG" ]]; then
        echo "[$level] $*" >&2
    else
        echo "[$level] $*"
    fi
}

die() {
    echo "[ERROR] $*" >&2
    exit 1
}

ensure_root() {
    [[ $EUID -eq 0 ]] || die "This script must be run as root."
}

create_build_user() {
    if ! id "$BUILD_USER" &>/dev/null; then
        log INFO "Creating build user: $BUILD_USER"
        useradd --system --create-home --home-dir /var/builduser --shell /bin/bash "$BUILD_USER"
        echo "$BUILD_USER ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/buildpkg
        chmod 0440 /etc/sudoers.d/buildpkg
    fi
}

find_pkgbuilds() {
    [[ -d "$INSTALL_DIR" ]] || die "Install directory not found: $INSTALL_DIR"
    mapfile -t PKGBUILD_DIRS < <(find "$INSTALL_DIR" -type f -name "PKGBUILD" -exec dirname {} \;)
    if [[ ${#PKGBUILD_DIRS[@]} -eq 0 ]]; then
        log INFO "No PKGBUILDs found in $INSTALL_DIR"
        exit 0
    fi
}

get_package_info() {
    local pkgbuild_file="$1"

    source "$pkgbuild_file" || {
        log ERROR "Failed to source $pkgbuild_file"
        return 1
    }

    [[ -n "${pkgname:-}" ]] || { log ERROR "Could not determine pkgname from $pkgbuild_file"; return 1; }
    [[ -n "${pkgver:-}"  ]] || { log ERROR "Could not determine pkgver from $pkgbuild_file"; return 1; }
    [[ -n "${pkgrel:-}"  ]] || { log ERROR "Could not determine pkgrel from $pkgbuild_file"; return 1; }

    PKGNAME="$pkgname"
    PKGVER="$pkgver"
    PKGREL="$pkgrel"
}

get_installed_version() {
    local pkgname="$1"
    pacman -Q "$pkgname" 2>/dev/null | awk '{print $2}' | sed 's/-[^-]*$//' || echo ""
}

get_upstream_version() {
    local pkg_dir="$1"
    local pkgname="$2"
    local version_script="$pkg_dir/version.sh"

    if [[ ! -f "$version_script" ]]; then
        echo -e "\e[31m[WARN] [$pkgname] No version.sh found — skipping\e[0m" >&2
        return 1
    fi

    if [[ ! -x "$version_script" ]]; then
        echo -e "\e[31m[WARN] [$pkgname] version.sh is not executable — skipping\e[0m" >&2
        return 1
    fi

    local upstream
    upstream=$(bash "$version_script" 2>/dev/null) || {
        log ERROR "[$pkgname] version.sh failed"
        return 1
    }

    upstream="${upstream// /}"
    if [[ -z "$upstream" ]]; then
        log ERROR "[$pkgname] version.sh produced no output"
        return 1
    fi

    echo "$upstream"
}

update_pkgbuild_version() {
    local pkgbuild_file="$1"
    local new_ver="$2"

    sed -i "s/^pkgver=.*/pkgver=${new_ver}/" "$pkgbuild_file"
    sed -i "s/^pkgrel=.*/pkgrel=1/" "$pkgbuild_file"

    log INFO "[$PKGNAME] PKGBUILD updated → pkgver=${new_ver} pkgrel=1"
}

build_and_install_package() {
    local pkg_dir="$1"
    local pkgbuild_file="$pkg_dir/PKGBUILD"

    get_package_info "$pkgbuild_file" || return

    echo
    echo "========== [$PKGNAME] =========="

    local upstream
    if ! upstream=$(get_upstream_version "$pkg_dir" "$PKGNAME"); then
        echo "==============================="
        return
    fi

    local installed
    installed=$(get_installed_version "$PKGNAME")

    log DEBUG "[$PKGNAME] installed=$installed upstream=$upstream"

    if [[ "$upstream" == "$installed" ]]; then
        log INFO "[$PKGNAME] ✅ Up-to-date: $upstream"
        echo "==============================="
        return
    fi

    log INFO "[$PKGNAME] Update needed: $installed → $upstream"
    update_pkgbuild_version "$pkgbuild_file" "$upstream"

    local build_dir="/tmp/makepkg-${PKGNAME}-$$"
    mkdir -p "$build_dir"
    cp -r "$pkg_dir"/* "$build_dir/"
    chown -R "$BUILD_USER:$BUILD_USER" "$build_dir"

    if ! sudo -u "$BUILD_USER" bash -c "cd '$build_dir' && makepkg --noconfirm --syncdeps --clean -f"; then
        log ERROR "[$PKGNAME] Build failed"
        rm -rf "$build_dir"
        echo "==============================="
        FAILED_PACKAGES+=("$PKGNAME")  # Track failure
        return 1
    fi

    cd "$build_dir"
    mapfile -t pkg_files < <(find . -maxdepth 1 -type f -name "*.pkg.tar.*" ! -name "*-debug-*")
    if [[ ${#pkg_files[@]} -eq 0 ]]; then
        log ERROR "[$PKGNAME] No package files found after build"
        rm -rf "$build_dir"
        echo "==============================="
        FAILED_PACKAGES+=("$PKGNAME")  # Track failure
        return 1
    fi

    log INFO "[$PKGNAME] Installing..."
    if ! pacman -U --ask 4 "${pkg_files[@]}"; then
        log ERROR "[$PKGNAME] Installation failed"
        rm -rf "$build_dir"
        echo "==============================="
        FAILED_PACKAGES+=("$PKGNAME")  # Track failure
        return 1
    fi
    
    rm -rf "$build_dir"
    log INFO "[$PKGNAME] Installed successfully"
    echo "==============================="
}

main() {
    ensure_root
    create_build_user
    find_pkgbuilds

    for pkg_dir in "${PKGBUILD_DIRS[@]}"; do
        build_and_install_package "$pkg_dir" || true  # Continue even if one fails
        sleep 1
    done

    # Exit with error if any packages failed
    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        echo
        log ERROR "The following packages failed to build/install:"
        for pkg in "${FAILED_PACKAGES[@]}"; do
            log ERROR "  - $pkg"
        done
        exit 1
    fi
}

main "$@"
