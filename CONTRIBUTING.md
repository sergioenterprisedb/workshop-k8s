# Contributing

A hands-on workshop that runs a highly available **PostgreSQL cluster on
Kubernetes** with the **CloudNativePG / EDB Postgres for Kubernetes** operator,
on a single AWS EC2 host (Docker + k3d, 1 server / 3 agents), with MinIO
(backups), Prometheus + Grafana (monitoring), and a ttyd/tmux web terminal.
It is **multi-user**: one VM hosts `user1`..`userN`, each driving its own
cluster in its own namespace.

## Platform Requirements

| Platform | Requirement | Notes |
|----------|-------------|-------|
| macOS    | bash 3.2+ (default) | All scripts compatible |
| Linux    | bash 4.4+ | Ubuntu 20.04+ recommended |
| Windows  | WSL2 required | Ubuntu 20.04+ recommended inside WSL2 |

### Windows Setup
Native PowerShell and CMD are not supported.
Install WSL2 with Ubuntu before contributing:
1. Enable WSL2: `wsl --install`
2. Install Ubuntu from the Microsoft Store
3. All commands must be run from inside the WSL2 terminal

### AWS CLI
AWS CLI v2 must be configured with valid credentials before running
any provisioning command:
  aws configure

## Project structure

```
workshop-k8s-cnpg/
├── provision.sh    Main entry point: --infra-only | --full | --delete | --help
├── config.sh       Single source of truth for all configuration (sourced everywhere)
│
├── infra/          AWS infrastructure scripts (run from your machine)
│   ├── create.sh       VPC, IGW, subnet, SG, EC2 + 4 EBS volumes
│   ├── delete.sh       destroy everything tagged $TAG_NAME
│   └── templates/
│       └── user-data.sh    first-boot: format + mount the extra EBS volumes only
│
├── platform/       Platform installation scripts (run on the EC2 host)
│   ├── install.sh      orchestrator → setup/01..05
│   ├── setup/
│   │   ├── 01_system.sh    docker, kubectl, helm, k3d, cmctl, gum, tools
│   │   ├── 02_cluster.sh   k3d cluster, node labels, Prometheus/Grafana, MinIO
│   │   ├── 03_terminal.sh  ttyd + tmux web terminal (welcome user + `login`)
│   │   ├── 04_users.sh     create users, render per-user manifests, distribute lab + kubeconfig
│   │   └── 05_cnpg.sh      kubectl-cnpg plugin, cert-manager, CNPG operator, Barman Cloud plugin
│   └── resources/
│       ├── banner.txt          welcome-screen banner
│       ├── cnpg-dashboard.json  Grafana CloudNativePG dashboard
│       └── manifests/          *-template.yaml (envsubst → per-user manifests)
│
├── lib/            Shared libraries (copied into each user's home with the lab)
│   ├── logger.sh       leveled/colored logging + log_spinner / log_stream
│   ├── ui.sh           gum-based interactive helpers for lab scenarios
│   └── test_logger.sh  logger self-test
│
├── cnpg-hands-on/  DBA lab — copied into each user's home (~/cnpg-hands-on)
│   └── 01..12_*.sh     ordered scenarios (deploy→backup→restore→upgrade→failover)
│                       each sources ../lib/ui.sh; per-user manifests land in manifests/
│
└── docs/images/    architecture / screenshots
```

`logs/`, `infra/connect_ec2.sh`, and `infra/.last_public_ip` are generated at
runtime and git-ignored. The lab's `manifests/` directory is generated per user
by `04_users.sh` (rendered from `platform/resources/manifests/*-template.yaml`),
not committed.

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
and only formats and mounts the extra EBS volumes. Everything else (waiting for
SSH, `dnf update`, installing git, cloning the repo) is handled by
`provision.sh` over SSH once the instance is reachable — both `--infra-only`
and `--full` share this through `provision_instance()`.

Inside the EC2 host, the platform installs with `cd platform && ./install.sh`,
which runs `setup/01..05` in order (system → cluster → terminal → users → CNPG).
DBA participants open the ttyd web terminal (`http://<IP>:4200`), type `login`
and enter their username, land in `~/cnpg-hands-on`, and run the numbered
scripts `01_*` → `12_*` in order.

**Access:** Grafana `:3010` · MinIO console `:9010` · web terminal `:4200`
(default creds `admin` / `password` — change them in `config.sh`).

## How to contribute

- **English only** — code, comments, variable names, and docs.
- **Minimal comments** — explain the **why**, never restate the **what**.
- **No hardcoded values** — every infra/platform parameter lives in the root
  `config.sh`. Manifests are parameterized (see templates below).
- **`set -Eeuo pipefail`** at the top of every script (infra, platform, and lab).
- **Short file headers** — max 10 lines, wrapped in `# ---` delimiters
  (path, one-line purpose, prerequisites if non-obvious, usage for entry points).
- **Use the shared libraries**, don't reinvent them:
  - `lib/logger.sh` → `log_info / log_success / log_warn / log_error /
    log_section / log_spinner / log_stream / die` for infra/platform scripts.
  - `lib/ui.sh` → the `ui_*` helpers for interactive lab scenarios.
  No manual log-file redirections — `init_logger`/`finalize_logger` handle that.
- **Per-user isolation:** lab resources derive from `$USER` (namespace `$USER`,
  `cnpg-cluster-$USER`). Never hardcode a username.
- **Templates, not static YAML:** add new manifests under
  `platform/resources/manifests/` as `*-template.yaml`, parameterize with
  `${USER_NAME}` (and other env vars), and let `04_users.sh` render them per
  user via `envsubst`.
- **Structure:** scripts use `#!/usr/bin/env bash`, one function per step, and
  `main "$@"` at the end.

### Sourcing `config.sh` and the libraries

`BASH_SOURCE`-relative so paths resolve regardless of the invocation directory:

- `infra/*`, `platform/install.sh`: `…/pwd)/../config.sh`
- `platform/setup/*`: `…/pwd)/../../config.sh`
- Lab scripts source the bundled library, not `config.sh`:
  `source "${LAB_DIR}/lib/ui.sh"` (where `LAB_DIR` is the lab's parent dir).

## Script template (infra / platform)

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
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/logger.sh"

do_step() {
  log_section "Doing the step"
  # Comment only when the reason is non-obvious (workaround, constraint).
  some-command --flags
  log_success "Step done"
}

main() {
  # Resolve relative paths regardless of the invocation directory.
  cd "$(dirname "${BASH_SOURCE[0]}")"

  do_step
  # … more steps, in order …
}

main "$@"
```

## Authoring a lab scenario (`cnpg-hands-on/`)

Lab scripts are **interactive, guided demos** driven by `lib/ui.sh` (a thin
wrapper around [`gum`](https://github.com/charmbracelet/gum), installed by
`01_system.sh`). They are copied into each user's home together with `lib/`, so
they source the library by relative path and rely on `$USER` for isolation.

Create the next script as `cnpg-hands-on/NN_<name>.sh` following this skeleton:

```bash
#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# cnpg-hands-on/NN_<name>.sh
# One-line purpose of the scenario.
# -----------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${LAB_DIR}/lib/ui.sh"

LAB_USER="${USER}"
NAMESPACE="${LAB_USER}"
PUBLIC_IP="${PUBLIC_IP:-$(curl -fsS https://api.ipify.org || echo "<PUBLIC_IP>")}"

GRAFANA_URL="http://${PUBLIC_IP}:3010"
MINIO_URL="http://${PUBLIC_IP}:9010"

# Boxed instructions shown at the top of the step.
show_instruct() {
  ui_note "
Step NN - <Title>

<What the participant will do and learn in this step.>
  "
  ui_pause
}

# The guided walkthrough: explain, then run one command at a time.
play() {
  ui_info "Explain what the next command demonstrates"
  ui_command "kubectl get pods --selector=cnpg.io/cluster=cnpg-cluster-${USER} --label-columns role"
  ui_pause

  ui_info "Apply a per-user manifest rendered by 04_users.sh"
  ui_command "kubectl apply -f manifests/01-cnpg-cluster-${USER}.yaml"
  ui_pause

  ui_success "Step complete — go to step NN+1 !"
}

main() {
  clear
  show_instruct
  play
}

main "$@"
```

### `lib/ui.sh` helpers

| Helper | Purpose |
|---|---|
| `ui_note "<text>"` | Boxed multi-line panel — use for step instructions |
| `ui_section "<title>"` | Bordered section header |
| `ui_step "<n - label>"` | Highlighted step marker |
| `ui_info / ui_success / ui_warn / ui_error "<msg>"` | Colored status lines |
| `ui_command "<cmd>"` | Echo a fake prompt, "type" the command, then `eval` it — the core demo primitive (**trusted commands only**, it uses `eval`) |
| `ui_pause` | "Press Enter to continue …" — put one between commands |
| `ui_confirm "<q>"` | Yes/no prompt (returns 0/1) |
| `ui_input "<placeholder>"` | Read a line of text input |
| `ui_choose "a" "b" "c"` | Selection menu, prints the choice |
| `ui_spin "<title>" cmd …` | Spinner while a command runs |
| `ui_type "<text>" [delay]` | Typewriter effect without executing |
| `ui_login` | Welcome-screen helper: prompt for a username and `su -` into it |

Conventions for scenarios:

- Keep the `show_instruct` → `play` → `main` shape; `main` does `clear` first.
- Precede every `ui_command` with a short `ui_info` explaining *why*, and follow
  interactive/long-running commands with `ui_pause`.
- Reference per-user resources as `cnpg-cluster-${USER}` and manifests as
  `manifests/<NN>-...-${USER}.yaml` — never a hardcoded user or cluster name.
- End the step by pointing to the next one (`ui_success "… go to step NN+1 !"`).
- New cluster manifest? Add a `*-template.yaml` under
  `platform/resources/manifests/` (parameterized with `${USER_NAME}`) so
  `04_users.sh` renders it into each user's `manifests/`.

## Dependencies

- **Your machine:** AWS CLI v2 (authenticated), `bash`, `ssh`.
- **EC2 (installed by `01_system.sh`):** docker, k3d, kubectl, helm, cmctl,
  gum, plus `git`/`wget`/`tar`/`unzip`/`jq`/`yq`/`watch`. The web terminal
  (`ttyd` + `tmux`) is installed by `03_terminal.sh`.
- **Cluster (installed by `05_cnpg.sh` via Helm):** CloudNativePG operator
  (`cnpg/cloudnative-pg`), Barman Cloud plugin (`cnpg/plugin-barman-cloud`),
  cert-manager `v1.20.2`, plus MinIO + kube-prometheus-stack from `02_cluster.sh`.
  The `kubectl-cnpg` plugin is installed from the upstream script.
- **PostgreSQL images** (set in `config.sh`): `:16.4` (default) / `:16.5`
  (minor upgrade) / `:17` (major upgrade).

## Modification rules

- Don't break the `$USER`-based per-user isolation.
- New infra/platform parameter → `config.sh`; new manifest →
  `platform/resources/manifests/*-template.yaml` + `${USER_NAME}` + `envsubst`.
- Keep the `main()` + `main "$@"` pattern; use `log_*` (infra/platform) or
  `ui_*` (lab) instead of raw `echo`.
- Never modify here-doc bodies (`tmux.conf`, `profile.d`, systemd units,
  `.bash_profile`, embedded YAML/JSON).
- Test AWS scripts with a dedicated `MY_CIDR` and `TAG_NAME` — `delete.sh`
  removes **all** resources carrying the tag.

