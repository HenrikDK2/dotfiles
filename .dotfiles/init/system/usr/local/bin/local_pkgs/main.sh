#!/usr/bin/env bash
set -euo pipefail

BUILD_USER="buildpkg"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$SCRIPT_DIR/pkgs"

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

normalize_version() {
    local ver="$1"
    ver="${ver#*:}"
    ver=$(echo "$ver" | sed 's/-[0-9]$//')
    ver="${ver//-/_}"
    echo "$ver"
}

get_package_info() {
    local pkgbuild_file="$1"

    source "$pkgbuild_file" || {
        log ERROR "Failed to source $pkgbuild_file"
        return 1
    }

    [[ -n "$pkgname" ]] || { log ERROR "Could not determine pkgname from $pkgbuild_file"; return 1; }
    [[ -n "$pkgver" ]]  || { log ERROR "Could not determine pkgver from $pkgbuild_file"; return 1; }
    [[ -n "$pkgrel" ]]  || { log ERROR "Could not determine pkgrel from $pkgbuild_file"; return 1; }

    PKGNAME="$pkgname"
    PKGVER="$pkgver"
    PKGREL="$pkgrel"
    EPOCH="${epoch:-0}"
    FULL_VERSION=$(normalize_version "$PKGVER")
}

get_installed_version() {
    local pkgname="$1"
    local installed
    installed=$(pacman -Q "$pkgname" 2>/dev/null | awk '{print $2}' || echo "")
    normalize_version "$installed"
}

github_helper() {
    local pkgname="$1"
    local installed="$2"
    local source_url="$3"

    [[ -z "$source_url" ]] && return
    [[ "$source_url" =~ github\.com/([^/]+)/([^/]+) ]] || return

    local owner="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    local api_url="https://api.github.com/repos/$owner/$repo/releases/latest"
    
    log DEBUG "[$pkgname] Detected owner=$owner repo=$repo"
    log DEBUG "[$pkgname] GitHub API URL: $api_url"

    local latest_tag
    latest_tag=$(curl -sf "$api_url" | jq -r '.tag_name' 2>/dev/null) || return

    [[ -z "$latest_tag" || "$latest_tag" == "null" ]] && return

    latest_tag="${latest_tag#v}"
    latest_tag=$(normalize_version "$latest_tag")
    log DEBUG "[$pkgname] Normalized latest_tag: $latest_tag"

    echo "$latest_tag|GitHub"
}

git_helper() {
    local pkgname="$1"
    local pkg_dir="$2"
    local installed="$3"
    
    [[ ! -d "$pkg_dir/.git" ]] && return

    local has_updates=0
    (
        cd "$pkg_dir" || exit 2
        git fetch origin -q || exit 2
        [[ "$(git rev-parse @)" != "$(git rev-parse @{u})" ]] && has_updates=1
    ) || return

    [[ $has_updates -eq 1 ]] && echo "$installed|Git"
}

aur_helper() {
    local pkgname="$1"
    local installed="$2"
    local api_url="https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=$pkgname"
    
    local aur_version
    aur_version=$(curl -sf "$api_url" | jq -r '.results[0].Version // empty' 2>/dev/null) || return
    [[ -z "$aur_version" ]] && return
    
    aur_version=$(normalize_version "${aur_version#*:}")
    echo "$aur_version|AUR"
}

check_if_update_needed() {
    local pkgname="$1"
    local pkg_dir="$2"
    local source_url="${3:-}"
    local installed
    installed=$(get_installed_version "$pkgname")
    local latest_version=""
    local helper=""
    local no_version_helpers=()

    local result
    result=$(github_helper "$pkgname" "$installed" "$source_url" 2>/dev/null) || true
    if [[ -n "$result" ]]; then
        latest_version="${result%%|*}"
        helper="${result##*|}"
    else
        no_version_helpers+=("GitHub")
    fi

    if [[ -z "$latest_version" ]]; then
        result=$(git_helper "$pkgname" "$pkg_dir" "$installed" 2>/dev/null) || true
        if [[ -n "$result" ]]; then
            latest_version="${result%%|*}"
            helper="${result##*|}"
        else
            no_version_helpers+=("Git")
        fi
    fi

    if [[ -z "$latest_version" ]]; then
        result=$(aur_helper "$pkgname" "$installed" 2>/dev/null) || true
        if [[ -n "$result" ]]; then
            latest_version="${result%%|*}"
            helper="${result##*|}"
        else
            no_version_helpers+=("AUR")
        fi
    fi

    if [[ ${#no_version_helpers[@]} -gt 0 ]]; then
        local joined_helpers
        joined_helpers=$(printf " | %s" "${no_version_helpers[@]}")
        joined_helpers="${joined_helpers:3}"
        log DEBUG "[$pkgname] Helpers with no version: $joined_helpers"
    fi

    if [[ -z "$latest_version" ]]; then
        latest_version="$installed"
        helper="None"
    fi

    log DEBUG "[$pkgname] Installed=$installed Latest=$latest_version Helper=$helper"
    echo "${latest_version}|${helper}"

    [[ "$latest_version" != "$installed" ]]
}

build_and_install_package() {
    local pkg_dir="$1"
    local pkgbuild_file="$pkg_dir/PKGBUILD"
    get_package_info "$pkgbuild_file" || return
    local source_url="${source[0]:-}"

    echo
    echo "========== [$PKGNAME] =========="
    
    local check
    check=$(check_if_update_needed "$PKGNAME" "$pkg_dir" "$source_url") || true
    local src_version="${check%%|*}"
    local helper="${check##*|}"
    local installed
    installed=$(get_installed_version "$PKGNAME")

    if [[ "$src_version" == "$installed" ]]; then
        log INFO "[$PKGNAME] ✅ Up-to-date: $src_version (verified by $helper)"
        echo "==============================="
        return
    fi

    log INFO "[$PKGNAME] Update needed: $src_version"
    local build_dir="/tmp/makepkg-${PKGNAME}-$$"
    mkdir -p "$build_dir"
    cp -r "$pkg_dir"/* "$build_dir/"
    chown -R "$BUILD_USER:$BUILD_USER" "$build_dir"

    if ! sudo -u "$BUILD_USER" bash -c "cd '$build_dir' && makepkg --noconfirm --syncdeps --clean -f"; then
        log ERROR "[$PKGNAME] Build failed"
        rm -rf "$build_dir"
        echo "==============================="
        return 1
    fi

    cd "$build_dir"
    mapfile -t pkg_files < <(find . -maxdepth 1 -type f -name "*.pkg.tar.*" ! -name "*-debug-*")
    if [[ ${#pkg_files[@]} -eq 0 ]]; then
        log ERROR "[$PKGNAME] No package files found"
        rm -rf "$build_dir"
        echo "==============================="
        return 1
    fi

    log INFO "[$PKGNAME] Installing package..."
    pacman -U --noconfirm "${pkg_files[@]}"
    rm -rf "$build_dir"
    log INFO "[$PKGNAME] Installed successfully"
    echo "==============================="
}

main() {
    ensure_root
    create_build_user
    find_pkgbuilds

    for pkg_dir in "${PKGBUILD_DIRS[@]}"; do
        build_and_install_package "$pkg_dir"
    done
}

main "$@"
