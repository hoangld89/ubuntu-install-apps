# shellcheck shell=bash

do_azcopy() {
    if command -v azcopy &>/dev/null; then
        success "AzCopy already installed, skipping"
        return
    fi

    info "Installing AzCopy..."
    apt-get install -y wget tar

    step_tmpdir
    # aka.ms link always redirects to the latest v10 linux tarball
    if ! wget -q -O "$STEP_TMP/azcopy.tar.gz" "https://aka.ms/downloadazcopy-v10-linux" || [[ ! -s "$STEP_TMP/azcopy.tar.gz" ]]; then
        fail "Could not download AzCopy"
        return 1
    fi
    # tarball nests the binary in azcopy_linux_amd64_x.y.z/ — flatten with --strip-components
    tar -xzf "$STEP_TMP/azcopy.tar.gz" -C "$STEP_TMP" --strip-components=1
    install -m 755 "$STEP_TMP/azcopy" /usr/local/bin/azcopy

    success "AzCopy $(azcopy --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo 'ready') installed"
}

undo_azcopy() {
    info "Removing AzCopy..."
    rm -f /usr/local/bin/azcopy
    success "AzCopy removed"
}
