# shellcheck shell=bash

# Microsoft fonts, from two separate sources:
#   * ttf-mscorefonts-installer (multiverse) — Arial, Times New Roman, Courier
#     New, Georgia, Verdana, Trebuchet MS, Comic Sans, Impact, Andale, Webdings.
#     The EULA must be pre-accepted via debconf so the install is non-interactive.
#   * Calibri, Cambria, Consolas, Candara, Constantia, Corbel — the ClearType
#     ("Vista") faces MS never shipped stand-alone. They live inside PowerPoint
#     Viewer 2007; we download it and pull the .ttf/.ttc out with cabextract
#     (the long-standing community method).
# Each part guards its own already-installed state, so this is safe to re-run.
do_msfonts() {
    # fontconfig provides fc-list / fc-cache — required for the accurate checks.
    apt-get install -y fontconfig >/dev/null 2>&1 || apt-get install -y fontconfig

    # --- Core fonts: Arial, Times New Roman, … (ttf-mscorefonts-installer) ---
    if has_font 'Times New Roman'; then
        success "MS core fonts already installed (Arial / Times New Roman / …)"
    else
        info "Installing MS core fonts (Arial, Times New Roman, Courier New, Georgia, Verdana…)..."
        # The package lives in the `multiverse` component — enable it if missing.
        if ! apt-cache policy ttf-mscorefonts-installer 2>/dev/null | grep -q 'Candidate: [0-9]'; then
            add-apt-repository -y multiverse >/dev/null 2>&1 || true
            apt-get update >/dev/null 2>&1 || true
        fi
        # Pre-accept the EULA so apt doesn't stop for the interactive prompt.
        echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true \
            | debconf-set-selections 2>/dev/null || true
        local reinstall=()
        if pkg_installed ttf-mscorefonts-installer; then
            # The package downloads the fonts in its postinst; a failed fetch leaves it installed with no fonts.
            info "ttf-mscorefonts-installer is installed but its fonts are missing — reinstalling..."
            reinstall=(--reinstall)
        fi
        if apt-get install -y "${reinstall[@]}" ttf-mscorefonts-installer >/dev/null 2>&1 \
           || apt-get install -y "${reinstall[@]}" ttf-mscorefonts-installer; then
            fc-cache -f >/dev/null 2>&1 || true
            success "MS core fonts installed (Arial, Times New Roman, Courier New, Georgia, Verdana, …)"
        else
            warn "MS core fonts (ttf-mscorefonts-installer) failed — check network / multiverse repo"
        fi
    fi

    # --- Calibri + ClearType faces, extracted from PowerPoint Viewer 2007 ---
    if has_font 'Calibri'; then
        success "Calibri & ClearType fonts already installed"
        return
    fi
    info "Installing Calibri + ClearType fonts (Cambria, Consolas, Candara, Constantia, Corbel)..."
    apt-get install -y cabextract wget >/dev/null 2>&1 || apt-get install -y cabextract wget
    local vista_dir="/usr/local/share/fonts/vista"
    step_tmpdir
    local tmp="$STEP_TMP"
    local ppv="$tmp/PowerPointViewer.exe"
    # SourceForge mirror of the original MS installer (Microsoft pulled its own).
    if wget -q -O "$ppv" "https://master.dl.sourceforge.net/project/mscorefonts2/cabs/PowerPointViewer.exe?viasf=1"; then
        mkdir -p "$vista_dir"
        # The .exe is a self-extractor; ppviewer.cab inside it holds the fonts.
        if cabextract -L -F ppviewer.cab -d "$tmp" "$ppv" >/dev/null 2>&1 \
           && cabextract -L -F '*.tt?' -d "$vista_dir" "$tmp/ppviewer.cab" >/dev/null 2>&1; then
            chmod 644 "$vista_dir"/*.tt? 2>/dev/null || true
            fc-cache -f >/dev/null 2>&1 || true
            if has_font 'Calibri'; then
                success "Calibri & ClearType fonts installed (Cambria, Consolas, Candara, Constantia, Corbel)"
            else
                success "Calibri fonts extracted to $vista_dir; fontconfig cache refreshes on next login"
            fi
        else
            warn "Could not extract Calibri fonts from PowerPoint Viewer (cabextract failed)"
        fi
    else
        warn "Could not download PowerPoint Viewer for Calibri fonts (check network)"
    fi
}

undo_msfonts() {
    # Purge the core-fonts package and delete the extracted Calibri/ClearType
    # faces. apt_purge never aborts the run on failure.
    info "Removing Microsoft fonts (Arial/Times New Roman/Calibri/…)..."
    apt_purge ttf-mscorefonts-installer
    rm -rf /usr/local/share/fonts/vista
    fc-cache -f >/dev/null 2>&1 || true
    success "Microsoft fonts removed (core fonts + Calibri/ClearType)"
}
