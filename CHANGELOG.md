# RELEASE NOTES

## v1.1 (Work In Progress)

### AWS Provisioning

* Automatic AWS key pair creation and private key retrieval

### Project structure

Installation workflow simplified and standardized:

```text
 workshop-k8s-cnpg/
  ├── provision.sh                # Single entry point: --infra-only | --full | --delete
  ├── config.sh                   # Unified config — single source of truth (AWS + platform)
  ├── README.md
  ├── CONTRIBUTING.md             # Human contributor guide
  ├── AGENTS.md                   # Rules/patterns for AI assistants
  ├── CHANGELOG.md
  ├── .gitignore
  │
  ├── infra/                      # AWS provisioning (run from the admin's machine)
  │   ├── create.sh               #   create VPC/IGW/subnet/SG/EC2 + EBS volumes
  │   ├── delete.sh               #   tear down everything tagged TAG_NAME
  │   └── templates/
  │       ├── user-data-infra.sh  #   EC2 first-boot: disks only (infra-only mode)
  │       └── user-data-full.sh   #   EC2 first-boot: disks + clone + install (full mode)
  │
  ├── platform/                   # Platform install (runs on the EC2 host)
  │   ├── install.sh              #   orchestrator: runs setup/01..04 in order
  │   ├── setup/
  │   │   ├── 01_system.sh        #   system tools: docker, kubectl, helm, k3d, cmctl…
  │   │   ├── 02_cluster.sh       #   k3d cluster + node labels + Prometheus/Grafana + MinIO
  │   │   ├── 03_terminal.sh      #   ttyd + tmux web terminal
  │   │   └── 04_users.sh         #   create user1..userN, distribute lab + kubeconfig
  │   └── scripts/                # read-only helper CLIs (rich tables)
  │       ├── get_clusters.sh
  │       ├── get_pods.sh
  │       ├── get_pvc.sh
  │       └── get_status.sh
  │
  ├── lib/                        # Shared shell libraries
  │   ├── logger.sh               #   leveled/colored logging + log_spinner
  │   └── test_logger.sh          #   logger self-test suite
  │
  ├── lab/
  │   └── cnpg-hands-on/          # DBA lab (template copied into each user's home)
  │       ├── 01..25_*.sh         #   numbered CNPG scenarios (install→backup→failover→upgrade)
  │       ├── config.sh           #   lab-local config (ns-$(whoami), cluster-$(whoami)…)
  │       ├── commands.sh         #   print_* / kube helper functions
  │       ├── env.sh, set_context.sh, create_namespace.sh, install_secrets.sh
  │       ├── primary.sh, replica.sh, delete_barman_plugin.sh, delete_cert_manager.sh
  │       ├── sql/                #   create_data.sql, verify_data.sql
  │       └── templates/          #   CNPG cluster/backup/restore/minio YAML (envsubst)
  │
  ├── docs/
  │   └── images/                 # architecture / grafana / minio screenshots
  │
  ├── lib/.gitkeep, logs/.gitkeep # keep otherwise-empty dirs tracked
  └── logs/                       # runtime transcripts (git-ignored)
```

Goal:

* Simplified maintenance and collaboration
* Clear separation of concerns
* Easier and controlled troubleshooting
* Centralized configuration
* Add CONTRIBUTING.md

### Kubernetes Platform

* Simplified and dedicated script to full k3d cluster provisioning
* Standardized node labels
* Platform services isolated on dedicated node (colocated with cp)
    * Prometheus and Grafana deployed through Helm
    * Minio deployed through helm (AGPL3 Licence - community version)
    * Product deployment homogeneisation with Helm for concise setup 

### Workshop Users

* Simplifiaction of kubeconfig distribution
* Kubernetes aliases and workshop shortcuts are conserved
* Modern web terminal (maintained) ttyd + tmux (split feature) + prompt coloration

---

## Next Steps

* Workshop documentation refresh
* Contributor guide (`CONTRIBUTE.md`) (development pattern, structure, git organization)
* Tests scenarios playing (--full, --infra-only, --delete)
* Verify ttyd at the first web access (need refresh)
* Automated Grafana CNPG dashboard import 
* Refactor workshop utility scripts
* Platform load testing
* Integrate in the setup - CNPG kubectl plugin, Operator installation, CNPG-IO plugin (remains on admin part)
* Evaluate if small tools can be aliased instead of being encapsulated in a script file in git (clean repo) 
