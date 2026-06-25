
[![Generic badge](https://img.shields.io/badge/Version-1.1-blue.svg)](https://shields.io/)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/Naereen/StrapDown.js/graphs/commit-activity)
![Maintainer](https://img.shields.io/badge/maintainer-sergio.romera@enterprisedb.com-blue)
![Maintainer](https://img.shields.io/badge/maintainer-raphael.chir@enterprisedb.com-blue)

# Workshop: CloudNativePG Demo on EC2 (k3d + Docker)

This repository demonstrates how to run and operate a **PostgreSQL high-availability cluster on Kubernetes** using the **CloudNativePG / EDB Postgres for Kubernetes** operator.

The demo environment runs on a single AWS EC2 host and includes:

- **AWS EC2** + **Docker** + **k3d** (K3s in Docker): 1 server + 3 agents
- **CloudNativePG / EDB Postgres for Kubernetes** operator
- **MinIO** (S3-compatible object storage) for backups
- **Prometheus + Grafana** monitoring stack (with a CloudNativePG dashboard)
- **ttyd + tmux** web terminal for participants

It walks through common **Day-1 and Day-2 operations** for PostgreSQL on Kubernetes, and is built to run as a **multi-user** environment: one VM hosts `user1`..`userN`, each driving its own cluster in its own namespace.

---

## Architecture
```
EC2 Instance
│
├─ Docker
│
├─ k3d Kubernetes cluster (1 server + 3 agents)
│   │
│   ├─ CloudNativePG / EDB Postgres for Kubernetes Operator
│   ├─ MinIO (S3 Compatible Object Storage)
│   └─ Prometheus + Grafana
│
├─ ttyd web terminal (per-user shell access)
│
├─ User1 .. UserN
│   └─ PostgreSQL Cluster
│       ├─ Primary
│       ├─ Replica 1
│       └─ Replica 2
```
![Architecture](./docs/images/ec2-k8s-cloudnativepg-architecture.jpg)

## User roles
- **Admin** — provisions the AWS infrastructure and installs the platform.
- **DBA** — manages PostgreSQL clusters with the CloudNativePG operator.

## Features demonstrated

| Who   | Feature                       | Description                                                      |
|-------|-------------------------------|------------------------------------------------------------------|
| Admin | Plugin & Operator Install     | `kubectl-cnpg` plugin, **CloudNativePG operator**, and **Barman Cloud plugin** — installed automatically by the platform setup |
| DBA   | PostgreSQL Cluster Deployment | Create a highly available PostgreSQL cluster                     |
| DBA   | Object Storage (Barman)       | Attach **MinIO S3** for WAL archiving via the Barman Cloud plugin |
| DBA   | Insert Data                   | Generate workload with `pgbench` and connect via `psql`          |
| DBA   | Backup / Recovery             | Back up to **MinIO S3** (imperative & declarative) and restore  |
| DBA   | Switchover / Failover         | Promote a replica manually, or recover on primary failure        |
| DBA   | Rolling Updates               | Minor and major PostgreSQL upgrades (by copy and in place)       |
| DBA   | Fencing / Hibernation         | Isolate or pause a cluster                                       |
| DBA   | Monitoring                    | Use Grafana to monitor cluster health                           |

---

## Prerequisites

On your local machine:
- **AWS CLI v2** ([install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)), authenticated:
  ```bash
  export AWS_ACCESS_KEY_ID="<your-key-id>"
  export AWS_SECRET_ACCESS_KEY="<your-secret-access-key>"
  export AWS_SESSION_TOKEN="<your-token>"      # if using temporary credentials
  ```
- `bash` and `ssh`.

## 1. Configure

All settings live in a single root [`config.sh`](./config.sh). At minimum, set
your IP so the security group lets you in:

```bash
REGION="<aws-region>"
INSTANCE_TYPE="<instance-type>"
TAG_NAME="<tag-name>"
KEY_NAME="<key-name>"
MY_CIDR="<my-cidr>"     # your public IP/32 — run `curl ipinfo.io/ip` to find it
```

> The full list of parameters (users, MinIO/Grafana credentials, ports, …) is
> documented in [`CONTRIBUTING.md`](./CONTRIBUTING.md).

## 2. Provision

Everything is driven by the single entry point [`provision.sh`](./provision.sh):

```bash
# Infrastructure only — then install the platform yourself (see step 3):
./provision.sh --infra-only

# Or full automation — infrastructure + platform installed automatically over SSH:
./provision.sh --full

# Tear everything down (destroys all resources tagged $TAG_NAME):
./provision.sh --delete

# Show usage:
./provision.sh --help
```

Both modes provision the infrastructure (`infra/create.sh`), wait for SSH, then
clone the repo onto the instance. `--full` additionally runs the platform
installer over SSH. `--delete` asks you to retype `$TAG_NAME` to confirm.

`infra/create.sh` provisions a `t2.2xlarge` (Amazon Linux 2023, 8 vCPU / 32 GiB)
with **4 × 50 GiB gp3 disks** (root + extra volumes for k3d storage) and a
security group opening port **22** (SSH, restricted to `MY_CIDR`) plus **3010**
(Grafana), **9010** (MinIO console), and **4200** (ttyd) — the last three open to
`0.0.0.0/0` so participants can connect from anywhere. It also writes an SSH
shortcut:

```bash
./infra/connect_ec2.sh
```

> If SSH times out, check that your current IP is still within `MY_CIDR`
> (`curl ipinfo.io/ip`) and update `config.sh`.

## 3. Install the platform (Admin)

If you used `--full`, this is already done automatically — skip to step 4.

Otherwise, SSH into the instance, clone the repo, and run the installer:

```bash
sudo dnf install -y git
git clone https://github.com/sergioenterprisedb/workshop-k8s-cnpg.git ~/workshop-k8s-cnpg
cd ~/workshop-k8s-cnpg/platform
./install.sh
```

`install.sh` runs the five setup steps (`platform/setup/0*.sh`) in order, fully
automated:

1. **System** (`01_system.sh`) — docker, kubectl, helm, k3d, cmctl, and CLI tools
2. **Cluster** (`02_cluster.sh`) — k3d cluster, node labels, **Prometheus/Grafana** + **MinIO** (Helm)
3. **Terminal** (`03_terminal.sh`) — ttyd + tmux web terminal
4. **Users** (`04_users.sh`) — creates `user1`..`userN`, distributes the lab, per-user manifests, and kubeconfig
5. **CNPG** (`05_cnpg.sh`) — `kubectl-cnpg` plugin, **cert-manager**, the **CloudNativePG operator**, and the **Barman Cloud plugin**

CloudNativePG (plugin, operator, and Barman plugin) is now installed
automatically by step 5 — no manual preparation is required.

### Access
| Service       | URL                          | Credentials          |
|---------------|------------------------------|----------------------|
| Grafana       | `http://<EC2_IP>:3010`       | `admin` / `password` |
| MinIO console | `http://<EC2_IP>:9010`       | `admin` / `password` |
| Web terminal  | `http://<EC2_IP>:4200`       | `user[N]` / `password[N]` |

![Grafana](./docs/images/grafana.jpg)
![MinIO](./docs/images/minio.jpg)

> Optional: import the bundled CloudNativePG Grafana dashboard
> ([`platform/resources/cnpg-dashboard.json`](./platform/resources/cnpg-dashboard.json))
> via Grafana → Dashboards → New → Import (data source: Prometheus).

## 4. Run the scenarios (DBA)

Each participant opens the **web terminal** (`http://<EC2_IP>:4200`), which lands
on a welcome screen. Type `login`, enter your username (`user1`..`userN`), and
you arrive in `~/cnpg-hands-on` with your kube context already set to your own
namespace. Each user works in a dedicated namespace, and all resources are
suffixed with the username (e.g. `cnpg-cluster-user1`). Per-user manifests are in
the `manifests/` directory; the scripts use the `ui_*` helpers from `lib/ui.sh`
to walk through each step interactively.

Run the numbered scripts in order:

```bash
./01_check_environment.sh        # validate env: cluster topology, operator, Barman plugin, MinIO secret
./02_deploy_cluster.sh           # create the HA PostgreSQL cluster from a manifest
./03_check_cluster.sh            # inspect status, pods, services, volumes, and logs
./04_add_barman_plugin.sh        # attach the Barman Cloud object store (MinIO) for WAL archiving
./05_create_data.sh              # explore the cnpg plugin, generate data with pgbench, connect via psql
./06_backup_cluster.sh           # back up to MinIO (imperative kubectl cnpg + declarative Backup resource)
./07_restore_cluster.sh          # restore into a new cluster from backup, then scale out
./08_minor_upgrade.sh            # minor PostgreSQL upgrade (kubectl diff + apply)
./09_cluster_administration.sh   # switchover (promote a replica), hibernation / fencing
./10_major_upgrade.sh            # major upgrade by copy
./11_cluster-failover.sh         # simulate primary failure and observe automatic failover
./12_major_upgrade_in_place.sh   # in-place major upgrade
```

---

## Contributing

Repository structure, code conventions, the standard script template,
dependencies, and known issues are documented in
[`CONTRIBUTING.md`](./CONTRIBUTING.md).
