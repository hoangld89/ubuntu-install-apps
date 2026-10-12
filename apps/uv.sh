# shellcheck shell=bash

do_uv() {
    local uv="$REAL_HOME/.local/bin/uv"
    # Only the standalone installer leaves a receipt; without it `uv self update` always fails, so reinstall instead.
    if [[ -x "$uv" && -f "$REAL_HOME/.config/uv/uv-receipt.json" ]]; then
        info "Updating uv..."
        if su - "$REAL_USER" -c '"$HOME/.local/bin/uv" self update'; then
            success "uv $("$uv" --version 2>/dev/null | cut -d' ' -f2) is the latest release"
        else
            warn "uv update failed — run 'uv self update' later"
        fi
        return
    fi

    info "Installing uv for user '$REAL_USER'..."
    # PATH comes from the Tool-integrations block, so the installer must not edit the rc files itself.
    run_remote_script "$REAL_USER" "env UV_NO_MODIFY_PATH=1 sh" https://astral.sh/uv/install.sh \
        || { fail "uv installer failed"; return 1; }
    if [[ ! -x "$uv" ]]; then
        fail "uv installer did not produce ~/.local/bin/uv"
        return 1
    fi
    success "uv $("$uv" --version 2>/dev/null | cut -d' ' -f2) installed for '$REAL_USER'"
}

undo_uv() {
    info "Removing uv..."
    su - "$REAL_USER" -c 'uv="$HOME/.local/bin/uv"; "$uv" tool uninstall --all; "$uv" python uninstall --all' &>/dev/null || true
    # Tool and python3.x links left behind when uv itself was already broken.
    find "$REAL_HOME/.local/bin" -maxdepth 1 -lname "$REAL_HOME/.local/share/uv/*" -delete 2>/dev/null || true
    rm -rf "$REAL_HOME/.local/share/uv" "$REAL_HOME/.cache/uv" "$REAL_HOME/.config/uv/uv-receipt.json"
    rm -f "$REAL_HOME/.local/bin/uv" "$REAL_HOME/.local/bin/uvx"
    success "uv removed (binaries, Python installs, tools & cache)"
}
