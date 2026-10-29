# shellcheck shell=bash

has_intel_gpu() { grep -qsx 0x8086 /sys/class/drm/card*/device/vendor; }

do_vaapi() {
    # AMD's VA-API driver ships inside Mesa; Intel's lives in a separate package Ubuntu does not install.
    if ! has_intel_gpu; then
        success "No Intel GPU — VA-API comes with Mesa, skipping"
        return
    fi
    if pkg_up_to_date intel-media-va-driver-non-free && pkg_up_to_date vainfo; then
        success "Intel VA-API driver already installed, skipping"
        return
    fi
    info "Installing the Intel VA-API driver..."
    ensure_multiverse intel-media-va-driver-non-free
    apt-get install -y intel-media-va-driver-non-free vainfo
    if vainfo --display drm 2>/dev/null | grep -q 'VAProfile'; then
        success "Intel VA-API driver installed (hardware video decode & encode)"
    else
        warn "Intel VA-API driver installed, but vainfo lists no profiles — GPUs older than Broadwell need i965-va-driver"
    fi
}

undo_vaapi() {
    info "Removing the Intel VA-API driver..."
    apt_purge intel-media-va-driver-non-free vainfo
    success "Intel VA-API driver removed"
}
