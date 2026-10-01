# shellcheck shell=bash

do_mirror() {
    info "Switching APT mirror to ${MIRROR_HOST}..."

    local found=0 f staged changed=()
    local targets=(
        /etc/apt/sources.list                                       # legacy
        /etc/apt/sources.list.d/ubuntu.sources                      # deb822 (24.04+)
    )

    step_tmpdir
    for f in "${targets[@]}"; do
        if [[ -f "$f" ]] && awk '!/security\.ubuntu\.com/ && /https?:\/\/[a-zA-Z0-9._-]+\/ubuntu/ { found = 1 } END { exit !found }' "$f"; then
            found=1
            staged="$STEP_TMP/${f##*/}"
            sed -E '/security\.ubuntu\.com/!s#https?://[a-zA-Z0-9._-]+/ubuntu#http://'"${MIRROR_HOST}"'/ubuntu#g' "$f" > "$staged"
            cmp -s "$staged" "$f" && continue
            [[ -e "$f.bak" ]] || cp -p "$f" "$f.bak"
            cp -p "$f" "$staged.prev"
            cat "$staged" > "$f"
            changed+=("$f")
            success "Updated $(basename "$f") (backup: ${f##*/}.bak)"
        fi
    done

    if [[ $found -eq 0 ]]; then
        warn "No Ubuntu archive entries found — mirror left unchanged"
        return
    fi
    if [[ ${#changed[@]} -eq 0 ]]; then
        success "APT already uses ${MIRROR_HOST}, skipping"
        return
    fi

    if ! apt-get update; then
        fail "apt-get update failed on ${MIRROR_HOST} — restoring the previous sources"
        for f in "${changed[@]}"; do
            cat "$STEP_TMP/${f##*/}.prev" > "$f"
        done
        apt-get update || true
        return 1
    fi
    success "APT mirror switched to ${MIRROR_HOST}"
}

undo_mirror() {
    info "Restoring original APT mirror from backups..."
    local restored=0 f
    local targets=(
        /etc/apt/sources.list
        /etc/apt/sources.list.d/ubuntu.sources
    )
    for f in "${targets[@]}"; do
        if [[ -f "$f.bak" ]]; then
            mv -f "$f.bak" "$f"
            success "Restored $(basename "$f")"
            restored=1
        fi
    done
    if [[ $restored -eq 1 ]]; then
        apt-get update || true
        success "Original APT mirror restored"
    else
        warn "No mirror backup (*.bak) found — nothing to restore"
    fi
}
