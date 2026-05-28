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
├── provision.sh              # Entry point: --infra-only | --full | --delete  [-v]
├── config.sh                 # Single source of truth (AWS + platform), sourced everywhere
├── README.md / CHANGELOG.md / AGENTS.md
│
├── infra/                    # AWS provisioning (run from your machine)
│   ├── create.sh             #   VPC, IGW, subnet, SG, EC2 + 4 EBS volumes
│   ├── delete.sh             #   destroy everything tagged $TAG_NAME
│   └── templates/
│       └── user-data.sh      #   first-boot: disks, network, git, repo clone
│
├── platform/                 # Platform install (runs on the EC2 host)
│   ├── install.sh            #   orchestrator → setup/01..04
│   ├── setup/
│   │   ├── 01_system.sh      #   docker, kubectl, helm, k3d, cmctl, tools
│   │   ├── 02_cluster.sh     #   k3d cluster, node labels, Prometheus/Grafana, MinIO
│   │   ├── 03_terminal.sh    #   ttyd + tmux web terminal
│   │   └── 04_users.sh       #   create users, distribute lab + kubeconfig
│   └── scripts/              #   get_clusters|pods|pvc|status.sh (read-only views)
│
├── lib/
│   ├── logger.sh             # leveled/colored logging + log_spinner
│   └── test_logger.sh        # logger self-test
│
├── lab/cnpg-hands-on/        # DBA lab — copied into each user's home
│   ├── 01..25_*.sh           #   ordered scenarios (install→backup→failover→upgrade)
│   ├── config.sh             #   lab config (ns-$(whoami), cluster-$(whoami), images…)
│   ├── commands.sh           #   print_* / kube helper functions
│   ├── sql/ , templates/     #   demo SQL + CNPG YAML templates (envsubst)
│   └── *.sh                  #   env, set_context, create_namespace, install_secrets…
│
└── docs/images/              # architecture / screenshots
```

`logs/` (transcripts), `infra/connect_ec2.sh`, and `infra/.last_public_ip` are
generated at runtime and git-ignored.

## First configuration

Before anything else, open the root [`config.sh`](./config.sh) and set these
keys — the rest have sensible defaults:

| Variable | What to set | Why it matters |
|---|---|---|
| `MY_CIDR` | Your **organization CIDR** (e.g. `203.0.113.0/24`) or your **single IP** (`x.x.x.x/32`) | Opens SSH (port 22) on the security group **only** to this range. Too narrow and you lock yourself out; too wide and you expose the host. Find your IP with `curl ipinfo.io/ip`. |
| `WORKSHOP_REPO_URL` | The Git URL of **this** repository | In `--full` mode the EC2 instance clones from here via user-data. It must point to the repo (and fork) you actually want deployed. |
| `WORKSHOP_REPO_BRANCH` | The branch to deploy | `--full` checks out this branch on the instance. **Set it to your feature branch when testing changes** — otherwise the instance runs `main`, not your work in progress. |
| `REGION`, `INSTANCE_TYPE`, `KEY_NAME`, `TAG_NAME` | Your AWS region, instance size, SSH key name, resource tag | Standard AWS parameters; `TAG_NAME` is also what `--delete` targets. |

> ⚠️ `WORKSHOP_REPO_URL` / `WORKSHOP_REPO_BRANCH` only affect **`--full`**
> (automated install via user-data). In `--infra-only` you clone and install
> manually, so they are not used.

## Quick start

```bash
# 1. Edit config.sh — at least MY_CIDR, WORKSHOP_REPO_URL, WORKSHOP_REPO_BRANCH
#    (see "First configuration" above), plus region/key/tag.

# 2a. Infra only (then SSH in and run platform/install.sh yourself):
./provision.sh --infra-only

# 2b. Provision infrastructure and wait for SSH (platform install: see TODO):
./provision.sh --full

# 3. Tear it all down:
./provision.sh --delete
```

**First-boot template.** `infra/templates/user-data.sh` prepares the instance:
it formats/mounts the EBS volumes, waits for network, installs git, and clones
the workshop repo as `ec2-user` (the repo URL/branch are substituted by
`infra/create.sh` with `envsubst`). It does **not** run `platform/install.sh` —
the platform is installed separately.

> **Logging mechanism is being redesigned. See lib/logger.sh spec.** The
> automated `--full` log-streaming step in `provision.sh` is a TODO pending the
> new logger; for now both modes provision the instance and you run
> `platform/install.sh` over SSH.

Inside the EC2 host, the platform installs with `cd platform && ./install.sh`.
DBA participants connect via ttyd (`http://<IP>:4200`) or SSH, land in
`~/cnpg-hands-on`, and run the numbered scripts `06_*` → `25_*` in order.

**Access:** Grafana `:3010` · MinIO console `:9010` · web terminal `:4200`
(default creds `admin` / `password` — change them in `config.sh`).

## Conventions

- **Config-driven:** no magic values in logic. Put parameters in the root
  `config.sh` (infra + platform, exported) or `lab/cnpg-hands-on/config.sh`.
- **Per-user isolation:** names derive from `$(whoami)` (`ns-<user>`,
  `cluster-<user>`). Never hardcode a username.
- **Templates, not static YAML:** parameterize `templates/*.yaml` with `${var}`
  and render via `envsubst > "$TMP/<name>.yaml"` before `kubectl apply`.
- **Structure:** `platform/`/`infra/` scripts use `#!/usr/bin/env bash`,
  `set -Eeuo pipefail`, one function per step, and `main "$@"` at the end.
- **Logging:** `platform/`/`infra/` use `lib/logger.sh`
  (`log_info|success|warning|error|section|debug|spinner`). The lab uses
  `commands.sh` `print_*` helpers and deliberately skips strict mode (don't
  break a live demo).
- **Sourcing `config.sh`** (`BASH_SOURCE`-relative, resolves to repo root):
  - `infra/*`, `platform/install.sh`: `…/pwd)/../config.sh`
  - `platform/setup/*`, `platform/scripts/*`: `…/pwd)/../../config.sh`
- **Kube calls:** use `${kubectl_cmd}` / `${kubectl_cnp}`, not raw binaries.
- **DBA scenario numbering** is the workshop order; `05` and `17` are
  intentionally absent.

## Script template

Every `platform/` and `infra/` script follows this skeleton:

```bash
#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# <path>/<name>.sh
#
# Purpose      : <what this script does>
# Prerequisites: <what must exist/run first>
# Caller       : <who runs it, e.g. platform/install.sh>
# -----------------------------------------------------------------------------
set -Eeuo pipefail

# logger.sh FIRST (defines ${LOG_FILE}, log_* and log_spinner), then config.sh.
# Depth: ../  from infra/ and platform/install.sh ; ../../ from platform/setup|scripts.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/logger.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config.sh"

do_step() {
  log_section "Human-readable step name"
  log_debug "Variable values: ${SOME_VAR}"          # versions, ports, paths
  log_info "About to do the thing"

  # Wrap installs/downloads; spinner for long ops. Redirect command output to
  # the log file (except output captured into a variable).
  if log_spinner "Doing the thing" some-long-command --flags; then
    log_success "Thing done"
  else
    log_error "Thing failed"
    return 1
  fi

  # Verify the result (command -v / --version / kubectl get / file checks).
  command -v thing >/dev/null && log_success "thing installed: $(thing --version)"
}

main() {
  local start_time end_time duration
  start_time="$(date +%s)"

  log_section "Starting <task>"
  do_step
  # … more steps, in order …

  end_time="$(date +%s)"
  duration=$(( end_time - start_time ))
  log_section "<task> complete"
  log_info "Total duration: ${duration}s"
}

main "$@"
```

Rules of thumb: comment the **why**, not the what; one function per step;
`log_warning` for non-fatal issues; never modify here-doc bodies. See
[`AGENTS.md`](./AGENTS.md) for the full checklist.

Lab scripts (`lab/cnpg-hands-on/`) are simpler — `#!/bin/bash`, `source
./config.sh` at the top, `print_*` helpers from `commands.sh`, and no strict
mode.

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
- Keep the `main()` + `main "$@"` pattern; reuse `logger.sh` / `commands.sh`
  for output.
- Test AWS scripts with a dedicated `MY_CIDR` and `TAG_NAME` — `delete.sh`
  removes **all** resources carrying the tag.

## Known issues (avoid reproducing)

- `lab/cnpg-hands-on/config.sh` references undefined `${bucket}` where the real
  variable is `${s3_bucket}` (`object_storage_bucket` / `s3_destination_path`).
- A few lab scripts print messages mentioning a `yaml/` or `./docs/` directory
  that doesn't exist; the actual commands correctly use `$TMP`.
- `README.md` is partially outdated (old `platform/minio|prometheus|shellinabox`
  dirs, `install_ec2.sh`) and cites a `workshop-k8s` repo / a different
  maintainer than `config.sh`. Trust the scripts over the README.
