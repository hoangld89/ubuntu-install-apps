# shellcheck shell=bash

# Ubuntu 26.04 has no /etc/sysctl.conf and systemd-sysctl only reads sysctl.d.
SWAPPINESS_CONF=/etc/sysctl.d/99-swappiness.conf

# The Ubuntu installer provisions /swap.img — reuse it rather than stacking a second swap file.
resolve_swapfile() {
    if grep -q '^/swap.img[[:space:]]' /etc/fstab 2>/dev/null; then echo /swap.img; else echo /swapfile; fi
}

remove_swapfile() {
    local f="$1"
    if swapon --show=NAME --noheadings | grep -qx "$f"; then
        swapoff "$f" || { fail "Cannot swapoff $f (not enough free RAM to page it back in?)"; return 1; }
    fi
    rm -f "$f"
    sed -i "\#^${f}[[:space:]]#d" /etc/fstab
}

do_swap() {
    info "Configuring 8GB swap with swappiness 10..."

    local swapfile size
    swapfile=$(resolve_swapfile)
    # Earlier runs stacked /swapfile on top of the installer's /swap.img.
    if [[ "$swapfile" == /swap.img ]] && { [[ -e /swapfile ]] || grep -q '^/swapfile[[:space:]]' /etc/fstab; }; then
        remove_swapfile /swapfile || return 1
        info "Removed extra /swapfile (reusing /swap.img)"
    fi

    size=$(stat -c%s "$swapfile" 2>/dev/null || echo 0)
    if [[ "$size" -ge $((8 * 1024 * 1024 * 1024)) ]]; then
        swapon --show=NAME --noheadings | grep -qx "$swapfile" || swapon "$swapfile" || return 1
        success "Swap 8GB already configured ($swapfile), skipping"
    else
        remove_swapfile "$swapfile" || return 1
        { fallocate -l 8G "$swapfile" && chmod 600 "$swapfile" && mkswap "$swapfile" >/dev/null && swapon "$swapfile"; } \
            || { fail "Failed to create $swapfile"; return 1; }
        success "Swap 8GB active ($swapfile)"
    fi
    grep -q "^${swapfile}[[:space:]]" /etc/fstab || echo "$swapfile none swap sw 0 0" >> /etc/fstab

    [[ -f /etc/sysctl.conf ]] && sed -i '/^vm.swappiness/d' /etc/sysctl.conf
    echo 'vm.swappiness=10' > "$SWAPPINESS_CONF"
    sysctl -q -w vm.swappiness=10 || return 1
    success "swappiness=10 (persistent via $SWAPPINESS_CONF)"
}

undo_swap() {
    info "Removing swap & resetting swappiness..."
    remove_swapfile /swapfile || return 1
    [[ -f /etc/sysctl.conf ]] && sed -i '/^vm.swappiness/d' /etc/sysctl.conf
    rm -f "$SWAPPINESS_CONF"
    sysctl -q -w vm.swappiness=60 || true
    if [[ "$(resolve_swapfile)" == /swap.img ]]; then
        success "Swappiness reset to default (60); kept the installer's /swap.img"
    else
        success "Swap removed, swappiness reset to default (60)"
    fi
}
