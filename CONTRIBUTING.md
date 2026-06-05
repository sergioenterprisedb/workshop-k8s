# Contributing

A hands-on workshop that runs a highly available **PostgreSQL cluster on
Kubernetes** with the **CloudNativePG / EDB Postgres for Kubernetes** operator,
on a single AWS EC2 host (Docker + k3d, 1 server / 3 agents), with MinIO
(backups), Prometheus + Grafana (monitoring), and a ttyd/tmux web terminal.
It is **multi-user**: one VM hosts `user1`..`userN`, each driving its own
cluster in its own namespace.

For AI-assistant rules and coding patterns, see [`AGENTS.md`](./AGENTS.md).

## Project structure

```
workshop-k8s-cnpg/
├── provision.sh    Main entry point: --infra-only | --full | --delete
├── config.sh       Single source of truth for all configuration (sourced everywhere)
│
├── infra/          AWS infrastructure scripts (run from your machine)
│   ├── create.sh       VPC, IGW, subnet, SG, EC2 + 4 EBS volumes
│   ├── delete.sh       destroy everything tagged $TAG_NAME
│   └── templates/
│       └── user-data.sh    first-boot: format + mount the 3 EBS volumes only
│
├── platform/       Platform installation scripts (run on the EC2 host)
│   ├── install.sh      orchestrator → setup/01..04
│   ├── setup/
│   │   ├── 01_system.sh    docker, kubectl, helm, k3d, cmctl, tools
│   │   ├── 02_cluster.sh   k3d cluster, node labels, Prometheus/Grafana, MinIO
│   │   ├── 03_terminal.sh  ttyd + tmux web terminal
│   │   └── 04_users.sh     create users, distribute lab + kubeconfig
│   └── scripts/        get_clusters|pods|pvc|status.sh (read-only views)
│
├── lib/            Shared libraries (logger coming soon)
│
├── lab/            Workshop lab content
│   └── cnpg-hands-on/  DBA lab — copied into each user's home
│       ├── 01..25_*.sh     ordered scenarios (install→backup→failover→upgrade)
│       ├── config.sh       lab config (ns-$(whoami), cluster-$(whoami), images…)
│       ├── commands.sh     print_* / kube helper functions
│       └── sql/ , templates/   demo SQL + CNPG YAML templates (envsubst)
│
└── docs/images/    architecture / screenshots
```

`logs/`, `infra/connect_ec2.sh`, and `infra/.last_public_ip` are generated at
runtime and git-ignored.

## First configuration

Before anything else, open the root [`config.sh`](./config.sh) and set these
keys — the rest have sensible defaults:

| Variable | What to set | Why it matters |
|---|---|---|
| `MY_CIDR` | Your **organization CIDR** (e.g. `203.0.113.0/24`) or your **single IP** (`x.x.x.x/32`) | Opens SSH (port 22) on the security group **only** to this range. Too narrow and you lock yourself out; too wide and you expose the host. Find your IP with `curl ipinfo.io/ip`. |
| `WORKSHOP_REPO_URL` | The Git URL of **this** repository | The instance clones from here during provisioning. It must point to the repo (and fork) you actually want deployed. |
| `WORKSHOP_REPO_BRANCH` | The branch to deploy | The instance checks out this branch. **Set it to your feature branch when testing changes** — otherwise the instance runs `main`, not your work in progress. |
| `REGION`, `INSTANCE_TYPE`, `KEY_NAME`, `TAG_NAME` | Your AWS region, instance size, SSH key name, resource tag | Standard AWS parameters; `TAG_NAME` is also what `--delete` targets. |

## Provisioning workflow

```bash
# 1. Edit config.sh — at least MY_CIDR, WORKSHOP_REPO_URL, WORKSHOP_REPO_BRANCH
#    (see "First configuration" above), plus region/key/tag.

# 2a. Infrastructure only — creates AWS infra, then prepares the instance
#     (waits for SSH, installs git, clones the repo). Install the platform
#     yourself afterwards: cd ~/workshop-k8s-cnpg/platform && ./install.sh
./provision.sh --infra-only

# 2b. Full provisioning — infra + instance preparation, then runs
#     platform/install.sh on the instance over SSH.
./provision.sh --full

# 3. Tear it all down — destroys all AWS resources tagged with $TAG_NAME.
./provision.sh --delete
```

**How preparation is split.** `infra/templates/user-data.sh` runs at first boot
and only formats and mounts the 3 EBS volumes. Everything else (waiting for
SSH, `dnf update`, installing git, cloning the repo) is handled by
`provision.sh` over SSH once the instance is reachable — both `--infra-only`
and `--full` share this through `provision_instance()`.

Inside the EC2 host, the platform installs with `cd platform && ./install.sh`.
DBA participants connect via ttyd (`http://<IP>:4200`) or SSH, land in
`~/cnpg-hands-on`, and run the numbered scripts `06_*` → `25_*` in order.

**Access:** Grafana `:3010` · MinIO console `:9010` · web terminal `:4200`
(default creds `admin` / `password` — change them in `config.sh`).

## How to contribute

- **English only** — code, comments, variable names, and docs.
- **Minimal comments** — explain the **why**, never restate the **what**.
- **No hardcoded values** — every parameter lives in the root `config.sh`
  (or `lab/cnpg-hands-on/config.sh` for the lab).
- **`set -Eeuo pipefail`** at the top of every `infra/` and `platform/` script.
- **Short file headers** — max 10 lines, wrapped in `# ---` delimiters
  (path, one-line purpose, prerequisites if non-obvious, usage for entry points).
- **No manual log-file redirections.** The logging mechanism is being
  rewritten; until `lib/logger.sh` lands, scripts print progress directly.
- **Per-user isolation:** names derive from `$(whoami)` (`ns-<user>`,
  `cluster-<user>`). Never hardcode a username.
- **Templates, not static YAML:** parameterize `templates/*.yaml` with `${var}`
  and render via `envsubst > "$TMP/<name>.yaml"` before `kubectl apply`.
- **Structure:** `infra/` / `platform/` scripts use `#!/usr/bin/env bash`,
  one function per step, and `main "$@"` at the end.

### Sourcing `config.sh`

`BASH_SOURCE`-relative so it resolves to the repo root regardless of the
invocation directory:

- `infra/*`, `platform/install.sh`: `…/pwd)/../config.sh`
- `platform/setup/*`, `platform/scripts/*`: `…/pwd)/../../config.sh`

## Script template

Every `infra/` and `platform/` script follows this skeleton:

```bash
#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# <path>/<name>.sh
# One-line purpose.
# Prerequisites: <what must exist/run first>   (only if non-obvious)
# Usage: <how to run it>                        (only for entry points)
# -----------------------------------------------------------------------------
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../config.sh"

do_step() {
  # Comment only when the reason is non-obvious (workaround, constraint).
  some-command --flags
}

main() {
  # Resolve relative paths regardless of the invocation directory.
  cd "$(dirname "${BASH_SOURCE[0]}")"

  do_step
  # … more steps, in order …
}

main "$@"
```

Lab scripts (`lab/cnpg-hands-on/`) are simpler — `#!/bin/bash`, `source
./config.sh` at the top, `print_*` helpers from `commands.sh`, and no strict
mode (don't break a live demo).

## Upcoming changes

- `lib/logger.sh` is being written from scratch (leveled, colored output).
- Once it lands, `log_*` functions will be added across the `infra/` and
  `platform/` scripts, replacing the current direct `echo` progress lines.

Until then, **do not** add `log_*` calls or reintroduce log-file redirections.

## Dependencies

- **Your machine:** AWS CLI v2 (authenticated), `bash`, `ssh`, `envsubst`.
- **EC2 (installed by `01_system.sh`):** docker, k3d, kubectl, helm, cmctl,
  kubectl-cnpg, rich-cli, ttyd, tmux, plus `git`/`jq`/`bc`/`envsubst`/`watch`.
- **Cluster:** CloudNativePG operator, Barman Cloud plugin `v0.11.0`,
  cert-manager `v1.19.4`, MinIO + kube-prometheus-stack (Helm),
  PostgreSQL images `:16.4` (default) / `:16.5` (minor) / `:17` (major).

## Modification rules

- Don't break the `$(whoami)` isolation.
- New parameter → `config.sh`; new manifest → template + `envsubst`.
- Keep the `main()` + `main "$@"` pattern.
- Never modify here-doc bodies (`tmux.conf`, `profile.d`, systemd units,
  `.bash_profile`, embedded YAML/JSON).
- Test AWS scripts with a dedicated `MY_CIDR` and `TAG_NAME` — `delete.sh`
  removes **all** resources carrying the tag.

## Known issues (avoid reproducing)

- `lab/cnpg-hands-on/config.sh` references undefined `${bucket}` where the real
  variable is `${s3_bucket}` (`object_storage_bucket` / `s3_destination_path`).
- A few lab scripts print messages mentioning a `yaml/` or `./docs/` directory
  that doesn't exist; the actual commands correctly use `$TMP`.
- `README.md` is partially outdated. Trust the scripts over the README.
