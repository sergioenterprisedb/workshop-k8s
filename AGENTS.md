# AGENTS.md

Operating rules for AI coding assistants working in this repository. Follow
them exactly. Human-oriented context lives in [`CONTRIBUTING.md`](./CONTRIBUTING.md).

Repo in one line: a multi-user CloudNativePG workshop — AWS provisioning
(`infra/`), platform install (`platform/`), DBA lab (`lab/cnpg-hands-on/`), and
a shared shell logging library (`lib/logger.sh`).

---

## 1. Refactoring roadmap (priority order)

> **Logging mechanism is being redesigned. See lib/logger.sh spec.**
> The legacy logging mechanism (per-script `LOG_FILE` redirections, the
> `SESSION_LOG` stream, and the SSH log-streaming in `provision.sh`) has been
> removed. Do not reintroduce it; the new logger is implemented separately.

Already done — do not redo:
- Root `config.sh` is the single source of truth (defines `SOURCE_ADMIN_PATH`,
  guards `HOME`/`USER`).
- `platform/setup/01..04` and `platform/install.sh` use the `log_*` helpers.
- `infra/create.sh` and `infra/delete.sh` follow the `function + main()` pattern;
  `infra/templates/user-data.sh` prepares the instance and clones the repo.
- `provision.sh` (root) orchestrates `--infra-only | --full | --delete`.

Pending, in priority order:
1. Fix the open bugs in CONTRIBUTING.md "Known issues": `${bucket}` → `${s3_bucket}`
   in `lab/cnpg-hands-on/config.sh`, and the `yaml/`/`./docs/` log-message
   mismatches in a few lab scripts.
2. Bring `README.md` fully in line with the current scripts (it is only partially
   refreshed).
3. Features: auto-redirect ttyd login to Grafana; parallelize independent
   deployment steps to cut setup time.

Do NOT migrate the `lab/cnpg-hands-on/` scripts to the logger unless explicitly
asked — they are intentionally interactive (no strict mode, `commands.sh`
`print_*` helpers).

---

## 2. Required header block (every `platform/`,`infra/`,`lib/` script)

```bash
#!/usr/bin/env bash
#
# <name>.sh — <one-line title>.
#
# Purpose      : <what it does>
# Prerequisites: <what must exist/run first>
# Caller       : <who runs it>
# Logs         : Structured progress on the console; full transcript in ${LOG_FILE}.
#
set -Eeuo pipefail
```

---

## 3. Logger integration

- Source the logger FIRST, then config — both via `BASH_SOURCE`-relative paths.
  Both `lib/logger.sh` and `config.sh` live at the repo root, so from
  `platform/setup/` the depth is two levels up:

```bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/logger.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"
```

- Functions: `log_info`, `log_success`, `log_warning`, `log_error`,
  `log_section`, `log_debug`, `log_spinner`.
- Always print through these — **never** a bare `echo` in business logic.
- `log_error` then `return 1` on any failure.
- `log_warning` for non-fatal issues (e.g. "user already exists, skipping").
- Never log secrets. Log a password *prefix*, never the full password.

---

## 4. Spinner usage

Wrap long-running operations (downloads, `dnf install`, `helm`, `k3d cluster
create`, `kubectl patch`, `cp -r`, `chown -R`, `systemctl daemon-reload`) and
branch on the result:

```bash
if log_spinner "Doing X" some long-running command --flags; then
  log_success "X done"
else
  log_error "X failed"
  return 1
fi
```

`log_spinner` runs the command, captures its output to `${LOG_FILE}`, and
returns the command's exit status.

---

## 5. Function pattern (apply to every function)

1. `log_section "<purpose>"` at the top.
2. `log_info` before each significant operation.
3. `log_debug` for variable values (versions, ports, paths, node/user names).
4. Redirect command output: `>> "${LOG_FILE}" 2>&1` on every command —
   EXCEPT (a) here-docs writing config files, and (b) commands whose output is
   captured into a variable or file (e.g. `… >"${HOME}/.kube/config"`).
5. Wrap installs/downloads in `if/else` → `log_success` / `log_error`+`return 1`.
6. Add a post-step verification (e.g. `command -v <tool>`, `<tool> --version`,
   `kubectl get …`, `rollout status`, file existence checks).

`main()` requirements:
- Start with `log_section`.
- Capture `start_time="$(date +%s)"`, compute and `log_info` the total duration
  at the end, and close with a `log_section "<...> complete"`.
- Preserve the existing call order of step functions.
- End the file with `main "$@"`.

---

## 6. Never modify

- **Here-doc bodies** — `tmux.conf`, `profile.d` scripts, systemd units,
  `.bash_profile`, embedded YAML/JSON. Not a single byte.
- **Existing logic, flags, helm values, kubectl/AWS commands** — wrap and log
  them; never change what they do.
- **`set -Eeuo pipefail`** (or `set -euo pipefail` where already present).
- **`set -m`-free background usage** in the spinner — keep it as-is.
- **Per-user isolation via `$(whoami)`** — `ns-<user>`, `cluster-<user>`.
- **The `id` existence check** before `useradd`.
- **Variable exports in `*config.sh`** that other scripts depend on.

---

## 7. Style rules

- English only — code, comments, variable names, log messages, docs. No French.
- Comment the WHY, never the WHAT. Inline comments only for non-obvious
  decisions, workarounds, or constraints.
- No magic values in logic — every parameter lives in the relevant `config.sh`.
- No hardcoded usernames, namespaces, or cluster names — derive from
  `$(whoami)` / config variables.
- Match the surrounding code's naming and idiom.
- Keep the `function + main()` structure; do not introduce a different layout.

---

## 8. Verify before finishing

- `bash -n <file>` passes.
- `BASH_SOURCE`-relative source paths resolve from the script's location.
- Here-doc bodies are byte-identical to the original (diff them).
- No French text remains.
- If you touched `lib/logger.sh`, re-run `lib/test_logger.sh` (must exit 0).
