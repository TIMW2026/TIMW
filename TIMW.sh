#!/bin/bash
set -euo pipefail
shopt -s nullglob

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CHROOT="${HOME:?HOME is not set}/chroot"
PKG_DIR="$BASE_DIR/PKG"
REPO="TIMW-AUR"
SUDO_KEEPALIVE_PID=""

PACKAGES=(
    llvm-git
    rust-git
    rust-bindgen-git
    spirv-headers-git
    spirv-tools-git
    spirv-llvm-translator-git
    libclc-git
    mesa-git
    linux-firmware-git
    linux-git
    wine-staging-git
    dxvk-mingw-git
    vkd3d-proton-mingw-git
    kodi-gles-git
)

declare -A PACKAGE_DIR=(
    [llvm-git]="1.llvm-git"
    [rust-git]="2.rust-git"
    [rust-bindgen-git]="3.rust-bindgen-git"
    [spirv-headers-git]="4.spirv-headers-git"
    [spirv-tools-git]="5.spirv-tools-git"
    [spirv-llvm-translator-git]="6.spirv-llvm-translator-git"
    [libclc-git]="7.libclc-git"
    [mesa-git]="8.mesa-git"
    [linux-firmware-git]="9.linux-firmware-git"
    [linux-git]="10.linux-git"
    [wine-staging-git]="11.wine-staging-git"
    [dxvk-mingw-git]="12.dxvk-mingw-git"
    [vkd3d-proton-mingw-git]="13.vkd3d-proton-mingw-git"
    [kodi-gles-git]="14.kodi-gles-git"
)

declare -A DEPENDS=(
    [llvm-git]="llvm-git"
    [rust-git]="llvm-git"
    [rust-bindgen-git]="llvm-git rust-git"
    [spirv-headers-git]="llvm-git rust-git rust-bindgen-git"
    [spirv-tools-git]="llvm-git rust-git rust-bindgen-git spirv-headers-git"
    [spirv-llvm-translator-git]="llvm-git rust-git rust-bindgen-git spirv-headers-git spirv-tools-git"
    [libclc-git]="llvm-git rust-git rust-bindgen-git spirv-headers-git spirv-tools-git spirv-llvm-translator-git"
    [mesa-git]="llvm-git rust-git rust-bindgen-git spirv-headers-git spirv-tools-git spirv-llvm-translator-git libclc-git"
    [linux-firmware-git]="llvm-git rust-git rust-bindgen-git spirv-headers-git spirv-tools-git spirv-llvm-translator-git libclc-git mesa-git"
    [linux-git]="llvm-git rust-git rust-bindgen-git spirv-headers-git spirv-tools-git spirv-llvm-translator-git libclc-git mesa-git linux-firmware-git"
    [wine-staging-git]="llvm-git rust-git rust-bindgen-git spirv-headers-git spirv-tools-git spirv-llvm-translator-git libclc-git mesa-git"
    [dxvk-mingw-git]="llvm-git rust-git rust-bindgen-git spirv-headers-git spirv-tools-git spirv-llvm-translator-git libclc-git mesa-git wine-staging-git"
    [vkd3d-proton-mingw-git]="llvm-git rust-git rust-bindgen-git spirv-headers-git spirv-tools-git spirv-llvm-translator-git libclc-git mesa-git wine-staging-git dxvk-mingw-git"
    [kodi-gles-git]="llvm-git rust-git rust-bindgen-git spirv-headers-git spirv-tools-git spirv-llvm-translator-git libclc-git mesa-git"
)

declare -A CHOSEN=()
SELECTED_PACKAGES=()
SELECT_BACK=0

cleanup() {
    if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

start_sudo_keepalive() {
    [[ -n "$SUDO_KEEPALIVE_PID" ]] && return 0

    sudo -v
    (
        while sleep 60; do
            sudo -n -v || exit
        done
    ) &
    SUDO_KEEPALIVE_PID=$!
}

require_chroot() {
    if [[ ! -d "$CHROOT/root" ]]; then
        echo "Chroot not found at: $CHROOT/root"
        echo "Choose 'Install/reinstall chroot' first."
        return 1
    fi
}

setup_chroot() {
    local answer

    read -r -p "This will delete and recreate $CHROOT. Continue? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        echo "Chroot setup cancelled."
        return 0
    fi

    start_sudo_keepalive
    sudo pacman -Syu --needed devtools

    [[ "$CHROOT" == "$HOME/chroot" && "$CHROOT" != "/" ]] || {
        echo "Unexpected chroot path; refusing to delete: $CHROOT" >&2
        return 1
    }

    sudo rm -rf -- "$CHROOT"
    mkdir -p "$CHROOT"

    mkarchroot "$CHROOT/root" base-devel

    sudo install -Dm644 "$BASE_DIR/makepkg.conf" \
        "$CHROOT/root/etc/makepkg.conf"
    sudo install -Dm644 "$BASE_DIR/pacman.conf" \
        "$CHROOT/root/etc/pacman.conf"
    sudo install -Dm644 "$BASE_DIR/rust.conf" \
        "$CHROOT/root/etc/makepkg.conf.d/rust.conf"

    sudo arch-nspawn "$CHROOT/root" pacman -Syu

    echo "Chroot setup complete."
}

update_host() {
    start_sudo_keepalive
    sudo pacman -Syu
}

update_chroot() {
    if ! require_chroot; then
        return 0
    fi

    start_sudo_keepalive
    sudo arch-nspawn "$CHROOT/root" pacman -Syu
}

find_local_package() {
    local wanted="$1"
    local file name best=""

    for file in "$PKG_DIR"/*.pkg.tar.zst; do
        [[ -f "$file" ]] || continue

        name="$(
            bsdtar -xOf "$file" .PKGINFO 2>/dev/null |
                awk -F ' = ' '$1 == "pkgname" { print $2; exit }'
        )" || name=""

        if [[ "$name" == "$wanted" ]]; then
            if [[ -z "$best" || "$file" -nt "$best" ]]; then
                best="$file"
            fi
        fi
    done

    [[ -n "$best" ]] || return 1
    printf '%s\n' "$best"
}

select_packages() {
    local allow_arbitrary="${1:-no}"
    local input token index package known
    local -a tokens

    while true; do
        CHOSEN=()
        SELECTED_PACKAGES=()
        SELECT_BACK=0

        echo
        for index in "${!PACKAGES[@]}"; do
            printf "%2d) %s\n" "$((index + 1))" "${PACKAGES[$index]}"
        done
        echo "Enter numbers or package names, separated by commas."
        echo "Enter 'all' for the listed packages, or '0'/'b' to go back."
        read -r -p "Selection: " input

        if [[ "${input,,}" == "0" || "${input,,}" == "b" || "${input,,}" == "back" ]]; then
            SELECT_BACK=1
            return 0
        fi

        if [[ "${input,,}" == "all" ]]; then
            for package in "${PACKAGES[@]}"; do
                CHOSEN["$package"]=1
                SELECTED_PACKAGES+=("$package")
            done
            return 0
        fi

        IFS=',' read -r -a tokens <<< "$input"
        local invalid=0

        for token in "${tokens[@]}"; do
            token="${token//[[:space:]]/}"

            if [[ "$token" =~ ^[0-9]+$ ]]; then
                index=$((10#$token - 1))

                if ((index < 0 || index >= ${#PACKAGES[@]})); then
                    echo "Selection out of range: $token"
                    invalid=1
                    break
                fi

                package="${PACKAGES[$index]}"
            else
                package="$token"

                if [[ ! "$package" =~ ^[[:alnum:]_.+@/-]+$ ]]; then
                    echo "Invalid package name: $package"
                    invalid=1
                    break
                fi

                known=0
                for token_check in "${PACKAGES[@]}"; do
                    if [[ "$package" == "$token_check" ]]; then
                        known=1
                        break
                    fi
                done

                if [[ "$allow_arbitrary" != "yes" && "$known" -eq 0 ]]; then
                    echo "Unknown build package: $package"
                    echo "Build selection is limited to the listed packages."
                    invalid=1
                    break
                fi
            fi

            if [[ -z "${CHOSEN[$package]:-}" ]]; then
                CHOSEN["$package"]=1
                SELECTED_PACKAGES+=("$package")
            fi
        done

        if ((invalid)); then
            continue
        fi

        if ((${#SELECTED_PACKAGES[@]} == 0)); then
            echo "Nothing selected."
            continue
        fi

        return 0
    done
}

install_dependency_in_chroot() {
    local package="$1"
    sudo arch-nspawn "$CHROOT/root" pacman -S --needed "$REPO/$package"
}

build_one_package() {
    local package="$1"
    local directory="$BASE_DIR/${PACKAGE_DIR[$package]}"
    local dependency local_file
    local -a make_args=()
    local -a output_files=()

    [[ -f "$directory/PKGBUILD" ]] || {
        echo "PKGBUILD not found: $directory/PKGBUILD" >&2
        return 1
    }

    for dependency in ${DEPENDS[$package]:-}; do
        if local_file="$(find_local_package "$dependency")"; then
            make_args+=(-I "$local_file")
        else
            echo "$dependency is not in $PKG_DIR; installing from $REPO in the chroot."
            install_dependency_in_chroot "$dependency"
        fi
    done

    echo
    echo "Building $package..."
    cd "$directory"
    makechrootpkg -c -r "$CHROOT" "${make_args[@]}"

    output_files=( "$directory"/*.pkg.tar.zst )
    if ((${#output_files[@]} == 0)); then
        echo "No package archives found after building $package." >&2
        return 1
    fi

    mkdir -p "$PKG_DIR"
    cp -f -- "${output_files[@]}" "$PKG_DIR/"
    echo "Copied build output to $PKG_DIR"
}

build_selected() {
    local package

    if ! require_chroot; then
        return 0
    fi
    select_packages no
    [[ "$SELECT_BACK" -eq 1 ]] && return 0

    start_sudo_keepalive
    mkdir -p "$PKG_DIR"

    for package in "${PACKAGES[@]}"; do
        if [[ -n "${CHOSEN[$package]:-}" ]]; then
            build_one_package "$package"
        fi
    done

    echo "Selected package builds complete."
}

install_selected() {
    local source target package package_spec

    select_packages yes
    [[ "$SELECT_BACK" -eq 1 ]] && return 0

    echo
    echo "Install source:"
    echo "1) $REPO"
    echo "2) Official Arch repositories"
    echo "0) Back"
    read -r -p "Choose source: " source

    case "${source,,}" in
        0|b|back) return 0 ;;
        1|2) ;;
        *)
            echo "Invalid source selection."
            return 0
            ;;
    esac

    echo
    echo "Install target:"
    echo "1) Host"
    echo "2) Chroot"
    echo "3) Both"
    echo "0) Back"
    read -r -p "Choose target: " target

    case "${target,,}" in
        0|b|back) return 0 ;;
        1|2|3) ;;
        *)
            echo "Invalid target selection."
            return 0
            ;;
    esac

    if [[ "$target" == "2" || "$target" == "3" ]]; then
        if ! require_chroot; then
            return 0
        fi
    fi

    start_sudo_keepalive

    for package in "${SELECTED_PACKAGES[@]}"; do
        if [[ "$source" == "1" && "$package" != */* ]]; then
            package_spec="$REPO/$package"
        else
            package_spec="$package"
        fi

        if [[ "$target" == "1" || "$target" == "3" ]]; then
            sudo pacman -S --needed "$package_spec"
        fi

        if [[ "$target" == "2" || "$target" == "3" ]]; then
            sudo arch-nspawn "$CHROOT/root" pacman -S --needed "$package_spec"
        fi
    done

    echo "Installation complete."
}

remove_selected() {
    local target package answer
    local -a selected=()

    select_packages yes
    [[ "$SELECT_BACK" -eq 1 ]] && return 0

    echo
    echo "Remove from:"
    echo "1) Host"
    echo "2) Chroot"
    echo "3) Both"
    echo "0) Back"
    read -r -p "Choose target: " target

    case "${target,,}" in
        0|b|back) return 0 ;;
        1|2|3) ;;
        *)
            echo "Invalid target selection."
            return 0
            ;;
    esac

    if [[ "$target" == "2" || "$target" == "3" ]]; then
        if ! require_chroot; then
            return 0
        fi
    fi

    for package in "${SELECTED_PACKAGES[@]}"; do
        selected+=("${package##*/}")
    done

    echo "Selected packages: ${selected[*]}"
    read -r -p "Continue with removal? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        echo "Removal cancelled."
        return 0
    fi

    start_sudo_keepalive

    if [[ "$target" == "1" || "$target" == "3" ]]; then
        sudo pacman -R -- "${selected[@]}"
    fi

    if [[ "$target" == "2" || "$target" == "3" ]]; then
        sudo arch-nspawn "$CHROOT/root" pacman -R -- "${selected[@]}"
    fi

    echo "Removal complete."
}

while true; do
    echo
    echo "Package manager menu"
    echo "1) Update host"
    echo "2) Update chroot"
    echo "3) Build selected packages"
    echo "4) Install packages (TIMW-AUR or Arch repos)"
    echo "5) Remove packages (host, chroot, or both)"
    echo "6) Install/reinstall chroot"
    echo "7) Exit"
    read -r -p "Choose an option: " choice

    case "$choice" in
        1) update_host ;;
        2) update_chroot ;;
        3) build_selected ;;
        4) install_selected ;;
        5) remove_selected ;;
        6) setup_chroot ;;
        7) exit 0 ;;
        *) echo "Invalid choice." ;;
    esac
done
