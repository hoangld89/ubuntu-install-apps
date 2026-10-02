# shellcheck shell=bash

RUN_TTY=0
SPIN_PID=""
STEP_LINE=""
RUN_FOOTER=""
STEP_PREFIX_W=25

fmt_secs() {
    if (( $1 >= 60 )); then printf -v REPLY '%dm%02ds' $(( $1 / 60 )) $(( $1 % 60 )); else REPLY="${1}s"; fi
}

strip_escapes() { sed $'s/\033\\[[0-9;?]*[A-Za-z]//g'; }

# The terminal gets the coloured line, the log a plain copy.
run_emit() {
    local l=$1
    (( UI_ASCII )) && { ui_ascii_text "$l"; l=$REPLY; }
    printf '%s\n' "$l"
    if [[ -n "$LOG_FILE" ]]; then printf '%s\n' "$l" | strip_escapes >> "$LOG_FILE"; fi
}

run_header() {
    run_emit ""
    run_emit "  ${C_MAUVE}${G_DIAMOND}${NC} ${BOLD}${C_TEXT}${ACTION_GERUND} ${STEP_TOTAL} apps${NC} ${C_OVERLAY}${G_DOT} log ${LOG_FILE}${NC}"
    run_emit ""
}

step_line() {  # $1 colour $2 glyph $3 name $4 detail $5 seconds → STEP_LINE
    local LC_ALL=C.UTF-8 t namecell detail gap
    fmt_secs "$5"; t=$REPLY
    ui_pad "$3" 20; namecell=$REPLY
    ui_trunc "$4" $(( UI_W - STEP_PREFIX_W - ${#t} - 1 )); detail=$REPLY
    gap=$(( UI_W - STEP_PREFIX_W - ${#detail} - ${#t} ))
    (( gap < 1 )) && gap=1
    ui_rep "$gap" ' '
    STEP_LINE="  ${1}${2}${NC} ${C_TEXT}${namecell}${NC} ${C_OVERLAY}${detail}${REPLY}${C_SUBTEXT}${t}${NC}"
}

run_footer() {  # $1 finished steps → RUN_FOOTER
    local LC_ALL=C.UTF-8 txt
    fmt_secs $(( SECONDS - RUN_START ))
    txt=" $1/${STEP_TOTAL} ${G_DOT} ${REPLY}"
    ui_bar "$1" "$STEP_TOTAL" $(( UI_W - ${#txt} )) "$C_MAUVE" "$G_PROG_F" "$G_PROG_E"
    RUN_FOOTER="  ${REPLY}${C_SUBTEXT}${txt}${NC}"
}

# Redraws the spinner line and the footer below it until the flag file goes away; it exits on its own, so no kill/"Terminated" noise.
spinner_start() {  # $1 step name
    (( RUN_TTY )) || return 0
    : > "$RUN_DIR/status"
    touch "$RUN_DIR/spinning"
    local name=$1 finished=$(( STEP_CURRENT - 1 )) parent=$$ started=$SECONDS
    (
        set +e
        local i=0 status n=${#G_SPIN[@]}
        while [[ -e "$RUN_DIR/spinning" ]] && kill -0 "$parent" 2>/dev/null; do
            status=""
            [[ -s "$RUN_DIR/status" ]] && read -r status < "$RUN_DIR/status"
            step_line "$C_MAUVE" "${G_SPIN[i % n]}" "$name" "$status" $(( SECONDS - started ))
            run_footer "$finished"
            printf '\r%s\033[K\n%s\033[K\033[1A\r' "$STEP_LINE" "$RUN_FOOTER"
            sleep 0.1
            i=$(( i + 1 ))
        done
    ) &
    SPIN_PID=$!
}

spinner_stop() {
    [[ -n "$SPIN_PID" ]] || return 0
    rm -f "$RUN_DIR/spinning"
    wait "$SPIN_PID" 2>/dev/null || true
    SPIN_PID=""
    printf '\r\033[K\n\033[K\033[1A\r'
}

step_report() {
    local tail_lines=() w l
    if (( $2 != 0 )); then
        mapfile -t tail_lines < <(tail -c +$(( $4 + 1 )) "$LOG_FILE" | strip_escapes | tr '\r' '\n' | grep -v '^[[:space:]]*$' | tail -n 15)
        step_line "$C_RED" "$G_ERR" "$1" "" "$3"
    elif (( ${#STEP_WARNINGS[@]} )); then
        step_line "$C_YELLOW" "$G_WARN" "$1" "$5" "$3"
    else
        step_line "$C_GREEN" "$G_OK" "$1" "$5" "$3"
    fi
    run_emit "$STEP_LINE"
    for w in "${STEP_WARNINGS[@]}"; do
        ui_trunc "$w" $(( UI_W - 6 ))
        run_emit "      ${C_YELLOW}${REPLY}${NC}"
    done
    (( $2 != 0 )) || return 0
    ui_trunc "$6" $(( UI_W - 6 ))
    run_emit "      ${C_RED}${REPLY}${NC}"
    for l in "${tail_lines[@]}"; do
        ui_trunc "$l" $(( UI_W - 8 ))
        run_emit "      ${C_OVERLAY}${G_PIPE} ${REPLY}${NC}"
    done
}

summary_row() {
    local namecell
    ui_pad "$3" $(( STEP_PREFIX_W - 7 )); namecell=$REPLY
    ui_trunc "$4" $(( UI_W - STEP_PREFIX_W + 1 ))
    run_emit "  ${5}${RB_V}${NC} ${1}${2}${NC} ${C_TEXT}${namecell}${NC} ${C_SUBTEXT}${REPLY}${NC}"
}

print_summary() {
    local LC_ALL=C.UTF-8 headline="$1" elapsed=$(( SECONDS - RUN_START ))
    local nf=${#RUN_FAILED[@]} nw=${#RUN_WARNED[@]} col="$C_GREEN" glyph="$G_OK" title="Done" stats i
    if [[ "$headline" == interrupted ]]; then
        col="$C_YELLOW"; glyph="$G_WARN"; title="Interrupted"
    elif (( nf > 0 )); then
        col="$C_RED"; glyph="$G_ERR"; title="Completed with errors"
    fi
    fmt_secs "$elapsed"
    stats="${title} ${G_DOT} ${RUN_SUCCEEDED} ${ACTION_PAST}"
    (( nf > 0 )) && stats+=" ${G_DOT} ${nf} failed"
    (( nw > 0 )) && stats+=" ${G_DOT} ${nw} with warnings"
    stats+=" ${G_DOT} ${REPLY}"

    run_emit ""
    if (( nf + nw == 0 )); then
        run_emit "  ${col}${glyph}${NC} ${BOLD}${C_TEXT}${stats}${NC}"
    else
        local head
        ui_trunc "${RB_H} ${stats} " $(( UI_W - 1 )); head=$REPLY
        ui_rep $(( UI_W - 1 - ${#head} )) "$RB_H"
        run_emit "  ${col}${RB_TL}${BOLD}${head}${NOBOLD}${REPLY}${NC}"
        for i in "${!RUN_FAILED[@]}"; do
            summary_row "$C_RED" "$G_ERR" "${RUN_FAILED[$i]}" "${RUN_FAILED_WHY[$i]}" "$col"
        done
        for i in "${!RUN_WARNED[@]}"; do
            summary_row "$C_YELLOW" "$G_WARN" "${RUN_WARNED[$i]}" "${RUN_WARNED_WHY[$i]}" "$col"
        done
        ui_rep $(( UI_W - 1 )) "$RB_H"
        run_emit "  ${col}${RB_BL}${REPLY}${NC}"
    fi

    local reasons=() r
    [[ -s "$RUN_DIR/reboot-reasons" ]] && mapfile -t reasons < <(sort -u "$RUN_DIR/reboot-reasons")
    [[ -f /var/run/reboot-required ]] && reasons+=("system packages need a reboot (/var/run/reboot-required)")
    if [[ ${#reasons[@]} -gt 0 ]]; then
        run_emit ""
        run_emit "  ${C_YELLOW}${G_REFRESH}${NC} ${BOLD}${C_TEXT}Reboot or re-login to apply${NC}"
        for r in "${reasons[@]}"; do
            run_emit "     ${C_OVERLAY}${G_INFO} ${r}${NC}"
        done
    fi

    if [[ -n "$LOG_FILE" ]]; then
        run_emit ""
        run_emit "  ${C_OVERLAY}Log${NC}  ${C_SUBTEXT}${LOG_FILE}${NC}"
    fi
    run_emit ""
}
