# grift

A tiny, dependency-free shell utility for managing **multiple Claude Code accounts** on one machine. Save the credentials for each account into a numbered slot and switch between them with a single command — handy if you juggle a personal account, a work account, and a few API/Max plans.

```
claude-save            # save the currently logged-in account into the next slot
claude-switch 2        # switch to slot 2
claude-accounts        # list saved slots
claude-delete          # delete a slot (interactive)
```

## How it works

Claude Code stores the credentials for the active account at `~/.claude/.credentials.json`. `grift` simply copies that file into `~/.claude/accounts/NNN.json` (a numbered slot) when you save, and copies a slot back over `~/.claude/.credentials.json` when you switch. No background processes, no config, no dependencies beyond `bash` and `coreutils`.

## Install

Clone the repo (or just grab the script) and source it from your shell rc:

```bash
git clone https://github.com/jasonsuhari/grift.git ~/.grift
echo 'source ~/.grift/grift.sh' >> ~/.bashrc   # or ~/.zshrc
source ~/.bashrc
```

That's it — the `claude-save`, `claude-switch`, `claude-accounts`, and `claude-delete` commands are now available in every new shell.

## Usage

### Save the current account
Log into Claude Code with the account you want to store, then:

```bash
claude-save
# Saved as slot 001  →  ~/.claude/accounts/001.json
```

Run it again after logging into a different account to save a second slot, and so on.

### Switch accounts

```bash
claude-switch 1     # 1, 01, and 001 all work
# Switched to account 001
```

Restart Claude Code (or start a new session) to pick up the swapped credentials.

### List saved accounts

```bash
claude-accounts
```

### Delete a saved account

```bash
claude-delete
```

## Security note

Saved slots are **plaintext copies of your Claude Code credentials**, stored under `~/.claude/accounts/`. Anyone with read access to that directory can use those tokens. Keep the directory private (`chmod 700 ~/.claude/accounts`), don't sync it to shared/cloud storage, and don't commit it to a repo. The `.gitignore` in this repo already excludes credential files.

## License

[MIT](LICENSE)
