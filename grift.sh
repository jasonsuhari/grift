# Claude Code multi-account / profile manager
#
# Source this file from your shell rc (~/.bashrc or ~/.zshrc):
#   source /path/to/grift.sh
#
# Usage:
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
