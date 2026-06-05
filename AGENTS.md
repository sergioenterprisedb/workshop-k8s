# AGENTS.md

Operating rules for AI coding assistants working in this repository. Follow
them exactly. Human-oriented context lives in [`CONTRIBUTING.md`](./CONTRIBUTING.md).

Repo in one line: a multi-user CloudNativePG workshop — AWS provisioning
(`infra/`), platform install (`platform/`), DBA lab (`lab/cnpg-hands-on/`), and
a shared library directory (`lib/`, logger pending).

---

## 1. Logger status — do not add `log_*` calls

`lib/logger.sh` is being **rewritten from scratch** and is not present yet. The
previous logging mechanism has been fully removed.

- **Do NOT** add `log_*` calls or any log-file redirection.
- **Do NOT** reintroduce any of the removed logging/streaming constructs or
  environment flags.
- Until the logger lands, scripts print progress **directly** (no redirection).
  Keep it that way.

Once `lib/logger.sh` exists, `log_*` functions will be introduced across
`infra/` and `platform/` — but only when explicitly requested.

Never migrate `lab/cnpg-hands-on/` scripts: they are intentionally interactive
(no strict mode, `commands.sh` `print_*` helpers).

---

## 2. config.sh is the single source of truth

- The root `config.sh` defines all AWS + platform configuration and is sourced
  by every `infra/` and `platform/` script. The lab has its own
  `lab/cnpg-hands-on/config.sh`.
- New parameter → add it to `config.sh`. Never hardcode values in logic.
- Source it `BASH_SOURCE`-relative so it resolves to the repo root from any
  invocation directory:

```bash
# infra/*, platform/install.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config.sh"
# platform/setup/*, platform/scripts/*
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"
```

---

## 3. Provisioning modes (how `provision.sh` works)

`provision.sh` is the entry point with three modes:

- `--infra-only` — runs `infra/create.sh`, then `provision_instance` (waits for
  SSH, `dnf update`, installs git, clones the repo). Prints the SSH command and
  the next step (`cd ~/workshop-k8s-cnpg/platform && ./install.sh`).
- `--full` — same as above, then runs `platform/install.sh` on the instance
  over SSH.
- `--delete` — runs `infra/delete.sh`, destroying all resources tagged
  `$TAG_NAME` (requires retyping the tag to confirm).

Key facts:
- `infra/templates/user-data.sh` runs at first boot and **only** formats/mounts
  the 3 EBS volumes. All other preparation happens in `provision.sh` over SSH.
- `infra/create.sh` records the instance public IP in `infra/.last_public_ip`;
  `provision.sh` reads it back. There is no instance-ID file.
- `provision_instance()` is the shared `wait_for_ssh` + `prepare_instance` path
  used by both `--infra-only` and `--full`.

---

## 4. Required header block (every `infra/`, `platform/`, `lib/` script)

Max 10 lines, wrapped in delimiters: path, one-line purpose, prerequisites (if
non-obvious), usage (entry points only).

```bash
#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# <path>/<name>.sh
# One-line purpose.
# Prerequisites: <what must exist/run first>   (only if non-obvious)
# Usage: <how to run it>                        (only for entry points)
# -----------------------------------------------------------------------------
set -Eeuo pipefail
```

---

## 5. Function and `main()` pattern

- One function per step; keep the existing call order.
- `main()` resolves relative paths first (`cd "$(dirname "${BASH_SOURCE[0]}")"`),
  then calls the step functions in order.
- End the file with `main "$@"`.
- Under `set -Eeuo pipefail`, a failing command already aborts the script — do
  not wrap every command in redundant error handling.
- For verification blocks, use a **positive** condition (`[ -d … ] && [ -f … ]`)
  returning `0`, not a leading negative test with `||` (which trips `set -e`).

---

## 6. Never modify

- **`lab/cnpg-hands-on/` scripts** — unless explicitly asked.
- **Here-doc bodies** — `tmux.conf`, `profile.d` scripts, systemd units,
  `.bash_profile`, embedded YAML/JSON. Not a single byte.
- **Existing logic, flags, helm values, kubectl/AWS commands** — never change
  what they do.
- **`set -Eeuo pipefail`**.
- **Per-user isolation via `$(whoami)`** — `ns-<user>`, `cluster-<user>`.
- **The `id` existence check** before `useradd`.
- **Functional `echo`s** that write to files/pipes (e.g. `… | sudo chpasswd`,
  `echo … > connect_ec2.sh`, `echo … >> /etc/fstab`).
- **Variable exports in `*config.sh`** that other scripts depend on.

---

## 7. Style rules

- English only — code, comments, variable names, docs. No French.
- Comment the WHY, never the WHAT. Inline comments only for non-obvious
  decisions, workarounds, or constraints.
- No magic values in logic — every parameter lives in the relevant `config.sh`.
- No hardcoded usernames, namespaces, or cluster names — derive from
  `$(whoami)` / config variables.
- Templates, not static YAML — parameterize with `${var}` and render via
  `envsubst` before `kubectl apply`.
- Match the surrounding code's naming and idiom.

---

## 8. Verify before finishing

- `bash -n <file>` passes for every modified script.
- `BASH_SOURCE`-relative source paths resolve from the script's location.
- Here-doc bodies are byte-identical to the original (diff them).
- No `log_*` calls or log-file redirections were added.
- No French text remains.
