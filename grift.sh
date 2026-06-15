# Claude Code multi-account / profile manager
#
# Source this file from your shell rc (~/.bashrc or ~/.zshrc):
#   source /path/to/grift.sh
#
# Usage:
#   grift                  — open the interactive account picker (TUI)
#   claude-save            — save current credentials as next numbered slot
#   claude-switch <n>      — switch to slot n (e.g. 1, 01, or 001)
#   claude-accounts        — list all saved slots
#   claude-delete          — delete a saved slot (interactive)

_CLAUDE_ACCOUNTS_DIR="$HOME/.claude/accounts"
_CLAUDE_CREDS="$HOME/.claude/.credentials.json"

claude-save() {
    mkdir -p "$_CLAUDE_ACCOUNTS_DIR"

    if [[ ! -f "$_CLAUDE_CREDS" ]]; then
        echo "No credentials file found at $_CLAUDE_CREDS — are you logged in?"
        return 1
    fi

    local num=1
    while [[ -f "$_CLAUDE_ACCOUNTS_DIR/$(printf '%03d' "$num").json" ]]; do
        ((num++))
    done
    local slot
    slot=$(printf '%03d' "$num")

    cp "$_CLAUDE_CREDS" "$_CLAUDE_ACCOUNTS_DIR/$slot.json"
    echo "Saved as slot $slot  →  $_CLAUDE_ACCOUNTS_DIR/$slot.json"
}

claude-switch() {
    if [[ -z "$1" ]]; then
        echo "Usage: claude-switch <slot>  (e.g. 1, 2, 001)"
        claude-accounts
        return 1
    fi

    local slot
    slot=$(printf '%03d' "$1")
    local file="$_CLAUDE_ACCOUNTS_DIR/$slot.json"

    if [[ ! -f "$file" ]]; then
        echo "No account at slot $slot."
        claude-accounts
        return 1
    fi

    cp "$file" "$_CLAUDE_CREDS"
    echo "Switched to account $slot"
}

claude-delete() {
    local dir="$_CLAUDE_ACCOUNTS_DIR"
    if [[ ! -d "$dir" ]] || [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
        echo "No saved accounts to delete. Run: claude-save"
        return 0
    fi

    echo "Select an account to delete:"
    local files=("$dir"/*.json)
    local slots=()
    for f in "${files[@]}"; do
        slots+=($(basename "$f" .json))
    done

    # Simple TUI: numbered list
    local i
    for i in "${!slots[@]}"; do
        echo "  $((i+1)). ${slots[$i]}"
    done

    local choice
    read -p "Enter the number of the account to delete (or 'q' to quit): " choice
    if [[ "$choice" == "q" ]]; then
        return 0
    fi

    if [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#slots[@]}" ]]; then
        local slot="${slots[$((choice-1))]}"
        local file="$dir/$slot.json"
        rm -i "$file"
        echo "Deleted account $slot"
    else
        echo "Invalid choice."
        return 1
    fi
}

claude-accounts() {
    local dir="$_CLAUDE_ACCOUNTS_DIR"
    if [[ ! -d "$dir" ]] || [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
        echo "No saved accounts yet. Run: claude-save"
        return 0
    fi
    echo "Saved accounts:"
    for f in "$dir"/*.json; do
        local slot
        slot=$(basename "$f" .json)
        echo "  $slot   →  $f"
    done
    echo ""
    echo "To delete an account, run: claude-delete"
}

# ─────────────────────────────────────────────────────────────────────────────
#  grift — interactive TUI account picker
#
#  A 2×3 grid of account "cards", each stamped with the Claude mascot. Navigate
#  with the arrow keys (or hjkl), switch with ⏎, and page through more than six
#  accounts with the ‹ › arrows. Pure bash + ANSI — no dependencies.
# ─────────────────────────────────────────────────────────────────────────────

# The Claude mascot, 12 columns wide.
_GRIFT_MASCOT=("  ██    ██  " "████████████" "███  ██  ███" "████████████" "██        ██")

# Center plain text $1 within width $2 (ignores ANSI — pass plain strings only).
_grift_center() {
    local s=$1 w=$2 len=${#1} l r
    l=$(( (w - len) / 2 )); (( l < 0 )) && l=0
    r=$(( w - len - l ));    (( r < 0 )) && r=0
    printf '%*s%s%*s' "$l" '' "$s" "$r" ''
}

# Scan the accounts dir into parallel arrays: slot id, subscription, active flag.
_grift_load() {
    GRIFT_SLOTS=(); GRIFT_SUBS=(); GRIFT_ACTIVE=()
    local f id sub
    shopt -s nullglob
    for f in "$GRIFT_DIR"/*.json; do
        id=$(basename "$f" .json)
        GRIFT_SLOTS+=("$id")
        sub=$(grep -o '"subscriptionType":"[^"]*"' "$f" 2>/dev/null | head -1 | sed 's/.*://; s/"//g')
        [[ -z $sub ]] && sub="account"
        GRIFT_SUBS+=("$sub")
        if [[ -f $GRIFT_CREDS ]] && cmp -s "$f" "$GRIFT_CREDS"; then
            GRIFT_ACTIVE+=(1)
        else
            GRIFT_ACTIVE+=(0)
        fi
    done
    shopt -u nullglob
}

# Emit the 10 lines of one card to stdout (or blank filler for empty cells).
_grift_card() {
    local gi=$1 W=14 cardW=16 R=$'\e[0m'
    if (( gi < 0 || gi >= ${#GRIFT_SLOTS[@]} )); then
        local i; for ((i = 0; i < 10; i++)); do printf '%*s\n' "$cardW" ''; done
        return
    fi

    local slot=${GRIFT_SLOTS[gi]} sub=${GRIFT_SUBS[gi]} active=${GRIFT_ACTIVE[gi]}
    local selected=0; (( gi == GRIFT_SEL )) && selected=1

    local bc tl tr bl br bch
    if (( selected )); then
        bc=$'\e[1;38;5;208m'; tl='┏'; tr='┓'; bl='┗'; br='┛'; bch='━'
    elif (( active )); then
        bc=$'\e[38;5;42m';    tl='╭'; tr='╮'; bl='╰'; br='╯'; bch='─'
    else
        bc=$'\e[38;5;240m';   tl='╭'; tr='╮'; bl='╰'; br='╯'; bch='─'
    fi
    local orange=$'\e[38;5;208m' dim=$'\e[2m' grn=$'\e[1;38;5;42m' wht=$'\e[1m'

    local hbar; printf -v hbar '%*s' "$W" ''; hbar=${hbar// /$bch}

    printf '%s\n' "${bc}${tl}${hbar}${tr}${R}"
    local m
    for m in "${_GRIFT_MASCOT[@]}"; do
        printf '%s\n' "${bc}│${R} ${orange}${m}${R} ${bc}│${R}"
    done
    printf '%s\n' "${bc}│${R}$(printf '%*s' "$W" '')${bc}│${R}"
    printf '%s\n' "${bc}│${R}${wht}$(_grift_center "Slot $slot" "$W")${R}${bc}│${R}"
    if (( active )); then
        printf '%s\n' "${bc}│${R}${grn}$(_grift_center "● ACTIVE" "$W")${R}${bc}│${R}"
    else
        printf '%s\n' "${bc}│${R}${dim}$(_grift_center "[$sub]" "$W")${R}${bc}│${R}"
    fi
    printf '%s\n' "${bc}${bl}${hbar}${br}${R}"
}

# Paint the whole frame in one shot.
_grift_render() {
    local cols rows
    cols=$(tput cols 2>/dev/null || echo 80)
    rows=$(tput lines 2>/dev/null || echo 24)

    local n=${#GRIFT_SLOTS[@]} perpage=6 ncols=3 W=14 gap=3
    (( GRIFT_SEL >= n )) && GRIFT_SEL=$(( n > 0 ? n - 1 : 0 ))
    local cardW=$(( W + 2 ))
    local gridW=$(( ncols * cardW + (ncols - 1) * gap ))
    local left=$(( (cols - gridW) / 2 )); (( left < 0 )) && left=0

    local ESC=$'\e' CLR=$'\e[K' NL=$'\n' R=$'\e[0m'
    local O1=$'\e[1;38;5;208m' DIM=$'\e[2m'
    local padL gapS
    printf -v padL '%*s' "$left" ''
    printf -v gapS '%*s' "$gap" ''

    local page=$(( GRIFT_SEL / perpage ))
    local pages=$(( (n + perpage - 1) / perpage )); (( pages < 1 )) && pages=1
    local start=$(( page * perpage ))

    # Title
    local tplain="grift — Claude Code accounts" tpad
    printf -v tpad '%*s' "$(( (cols - ${#tplain}) / 2 < 0 ? 0 : (cols - ${#tplain}) / 2 ))" ''
    local B="${ESC}[H${NL}${tpad}${O1}grift${R}${DIM} — Claude Code accounts${R}${CLR}${NL}${CLR}${NL}"

    if (( n == 0 )); then
        local m1="No accounts saved yet." m2="Log into Claude Code, then press  s  to save it." mp1 mp2
        printf -v mp1 '%*s' "$(( (cols - ${#m1}) / 2 < 0 ? 0 : (cols - ${#m1}) / 2 ))" ''
        printf -v mp2 '%*s' "$(( (cols - ${#m2}) / 2 < 0 ? 0 : (cols - ${#m2}) / 2 ))" ''
        B+="${NL}${NL}${mp1}${DIM}${m1}${R}${CLR}${NL}${NL}${mp2}${DIM}${m2}${R}${CLR}${NL}"
        local help="s save    q quit" hpad
        printf -v hpad '%*s' "$(( (cols - ${#help}) / 2 < 0 ? 0 : (cols - ${#help}) / 2 ))" ''
        B+="${NL}${NL}${hpad}${DIM}${help}${R}${CLR}${NL}"
        printf '%s' "${B}${ESC}[J"
        return
    fi

    # Grid
    local rr ln a b c
    local -a LA LB LC
    for rr in 0 1; do
        a=$(( start + rr * 3 )); b=$(( a + 1 )); c=$(( a + 2 ))
        readarray -t LA < <(_grift_card "$a")
        readarray -t LB < <(_grift_card "$b")
        readarray -t LC < <(_grift_card "$c")
        for ((ln = 0; ln < 10; ln++)); do
            B+="${padL}${LA[ln]}${gapS}${LB[ln]}${gapS}${LC[ln]}${CLR}${NL}"
        done
        (( rr == 0 )) && B+="${CLR}${NL}"
    done

    # Page dots
    B+="${CLR}${NL}"
    if (( pages > 1 )); then
        local dots="" k
        for ((k = 0; k < pages; k++)); do
            (( k == page )) && dots+="● " || dots+="○ "
        done
        local dpad; printf -v dpad '%*s' "$(( (cols - pages * 2) / 2 < 0 ? 0 : (cols - pages * 2) / 2 ))" ''
        B+="${dpad}${O1}${dots}${R}${CLR}${NL}"
    fi

    # Help + message
    local help="↑↓←→ move    ⏎ switch    s save    d delete    q quit" hpad
    printf -v hpad '%*s' "$(( (cols - ${#help}) / 2 < 0 ? 0 : (cols - ${#help}) / 2 ))" ''
    B+="${CLR}${NL}${hpad}${DIM}${help}${R}${CLR}${NL}"
    if [[ -n $GRIFT_MSG ]]; then
        local mpad; printf -v mpad '%*s' "$(( (cols - ${#GRIFT_MSG}) / 2 < 0 ? 0 : (cols - ${#GRIFT_MSG}) / 2 ))" ''
        B+="${CLR}${NL}${mpad}${O1}${GRIFT_MSG}${R}${CLR}${NL}"
    fi

    printf '%s' "${B}${ESC}[J"

    # Paging arrows, vertically centered beside the grid
    if (( pages > 1 )); then
        local arrowRow=14
        (( page > 0 ))         && printf '%s' "${ESC}[${arrowRow};$(( left - 1 > 0 ? left - 1 : 1 ))H${O1}‹${R}"
        (( page < pages - 1 )) && printf '%s' "${ESC}[${arrowRow};$(( left + gridW + 2 ))H${O1}›${R}"
    fi
}

_grift_move() {
    local n=${#GRIFT_SLOTS[@]}; (( n == 0 )) && return
    local i=$GRIFT_SEL col=$(( GRIFT_SEL % 3 ))
    case $1 in
        left)  (( col > 0 )) && (( GRIFT_SEL-- )) ;;
        right) (( col < 2 && i + 1 < n )) && (( GRIFT_SEL++ )) ;;
        up)    (( i >= 3 )) && (( GRIFT_SEL -= 3 )) ;;
        down)  (( i + 3 < n )) && (( GRIFT_SEL += 3 )) ;;
    esac
}

_grift_switch() {
    local n=${#GRIFT_SLOTS[@]}
    (( n == 0 )) && { GRIFT_MSG="No accounts yet — press s to save the current login"; return; }
    local slot=${GRIFT_SLOTS[GRIFT_SEL]}
    cp "$GRIFT_DIR/$slot.json" "$GRIFT_CREDS"
    _grift_load
    GRIFT_MSG="Switched to slot $slot — restart Claude Code to apply"
}

_grift_delete() {
    local n=${#GRIFT_SLOTS[@]}; (( n == 0 )) && return
    local slot=${GRIFT_SLOTS[GRIFT_SEL]}
    GRIFT_MSG="Delete slot $slot? (y/n)"
    _grift_render
    local c; IFS= read -rsn1 c
    if [[ $c == y || $c == Y ]]; then
        rm -f "$GRIFT_DIR/$slot.json"
        _grift_load
        (( GRIFT_SEL >= ${#GRIFT_SLOTS[@]} && GRIFT_SEL > 0 )) && (( GRIFT_SEL-- ))
        GRIFT_MSG="Deleted slot $slot"
    else
        GRIFT_MSG=""
    fi
}

grift() {
    GRIFT_DIR=$_CLAUDE_ACCOUNTS_DIR
    GRIFT_CREDS=$_CLAUDE_CREDS
    GRIFT_SEL=0
    GRIFT_MSG=""
    _grift_quit=0
    _grift_load

    printf '\e[?1049h\e[?25l'              # alternate screen + hide cursor
    trap '_grift_quit=1' INT TERM

    local key k2
    while (( ! _grift_quit )); do
        _grift_render
        IFS= read -rsn1 key || break
        case $key in
            '')   _grift_switch ;;                       # Enter
            $'\e')
                IFS= read -rsn2 -t 0.01 k2
                case $k2 in
                    '[A') _grift_move up ;;
                    '[B') _grift_move down ;;
                    '[C') _grift_move right ;;
                    '[D') _grift_move left ;;
                    '')   break ;;                       # lone Esc
                esac ;;
            k|K) _grift_move up ;;
            j|J) _grift_move down ;;
            l|L) _grift_move right ;;
            h|H) _grift_move left ;;
            s|S) claude-save >/dev/null 2>&1; _grift_load; GRIFT_MSG="Saved current login" ;;
            d|D) _grift_delete ;;
            q|Q) break ;;
        esac
    done

    trap - INT TERM
    printf '\e[?25h\e[?1049l'              # restore cursor + main screen
}
