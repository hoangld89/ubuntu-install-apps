# shellcheck shell=bash

DOTNET_ENV='export PATH="$PATH:$HOME/.dotnet/tools"; [ -x /usr/bin/dotnet ] && export DOTNET_ROOT="$(dirname "$(readlink -f /usr/bin/dotnet)")"'

do_abp() {
    if ! su - "$REAL_USER" -c "$DOTNET_ENV"'; command -v dotnet >/dev/null 2>&1'; then
        warn "ABP CLI needs the .NET SDK — select .NET SDK too, then re-run"
        return 1
    fi

    # The Volo.Abp.Studio.Cli global tool provides `abp` in ~/.dotnet/tools (on PATH via Tool integrations).
    if su - "$REAL_USER" -c "$DOTNET_ENV"'; command -v abp' &>/dev/null; then
        success "ABP CLI already installed, skipping"
        return
    fi

    info "Installing ABP CLI (Volo.Abp.Studio.Cli) for user '$REAL_USER'..."
    if su - "$REAL_USER" -c "$DOTNET_ENV"'
        set -e
        dotnet tool install -g Volo.Abp.Studio.Cli
    '; then
        success "ABP CLI installed for '$REAL_USER' (open a new shell, then run: abp)"
    else
        fail "ABP CLI install failed"
        return 1
    fi
}

undo_abp() {
    info "Removing ABP CLI..."
    su - "$REAL_USER" -c "$DOTNET_ENV"'
        command -v dotnet >/dev/null 2>&1 && dotnet tool uninstall -g Volo.Abp.Studio.Cli
    ' 2>/dev/null || true
    success "ABP CLI removed"
}
