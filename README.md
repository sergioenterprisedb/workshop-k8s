
[![Generic badge](https://img.shields.io/badge/Version-1.0-<COLOR>.svg)](https://shields.io/)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://GitHub.com/Naereen/StrapDown.js/graphs/commit-activity)
![Maintainer](https://img.shields.io/badge/maintainer-sergio.romera@enterprisedb.com-blue)

# Workshop: CloudNativePG Demo on EC2 (k3d + Docker)

This repository demonstrates how to run and operate a **PostgreSQL high-availability cluster on Kubernetes** using **CloudNativePG / EDB Postgres for Kubernetes Operator**.

The demo environment runs on:

- **AWS EC2**
- **Docker**
- **k3d (K3s in Docker)**
- **MinIO (S3 compatible storage)** for backups

It walks through common **Day-1 and Day-2 operations** for PostgreSQL in Kubernetes.
This demos have been built to run in a multiuser linux environment.

---

# Architecture
```
EC2 Instance
│
├─ Docker
│
├─ k3d Kubernetes cluster
│   │
│   ├─ CloudNativePG / EDB Postgres for Kubernetes Operator
│   ├─ MinIO (S3 Compatible Object Storage)
│   └─ Grafana/Prometheus
│
├─ User1
│   └─ PostgreSQL Cluster
│       ├─ Primary
│       ├─ Replica 1
│       └─ Replica 2
...
├─ UserN
│   └─ PostgreSQL Cluster
│       ├─ Primary
│       ├─ Replica 1
│       └─ Replica 2
```
![Architecture](./images/ec2-k8s-cloudnativepg-architecture.jpg)

# Types of users
We have 2 type of users for this workshop:
- Admin users: create the AWS infrastructure and install basic components
- DBA users: Manage PostgreSQL clusters with CloudNativePG operator.

# Features Demonstrated

This repository demonstrates the following operational capabilities:

| Who   | Feature                       | Description                                                      |
|-------|-------------------------------|------------------------------------------------------------------|
| Admin | Kubernetes Plugin Install     | Install `kubectl-cnpg` plugins for PostgreSQL cluster management |
| Admin | Operator Install              | Deploy **CloudNativePG operator**                                |
| DBA   | PostgreSQL Cluster Deployment | Create a highly available PostgreSQL cluster                     |
| DBA   | Insert Data                   | Demonstrate workload operations                                  |
| DBA   | Switchover                    | Promote a replica manually                                       |
| DBA   | Failover                      | Automatic promotion when primary fails                           |
| DBA   | Backup                        | Backup cluster to **MinIO S3 storage**                           |
| DBA   | Recovery                      | Restore cluster from backup                                      |
| DBA   | Scaling                       | Scale replicas up and down                                       |
| DBA   | Rolling Updates               | Minor and major PostgreSQL upgrades                              |
| DBA   | Fencing                       | Isolate a node to prevent split brain                            |
| DBA   | Monitoring                    | Use Grafana to monitor cluster health                            |
| DBA   | Operator Upgrade              | Upgrade Kubernetes operator                                      |

# Create AWS EC2 instance 
This workshop needs an AWS EC2 instance with this configuration:
- OS: AWS Linux (Ubuntu)
- Instance type: Tested with t2.2xLarge instance (8 vCPUs and 32GiB RAM)
- Network: create new security group 
- CPUs: Minimum 8 vCPUs
- RAM: 32GiB
- Storage:
  - 4 disks with this configuration:
  - Type: gp3
  - IOPS: 6000
  - Throughput: 300
- lsblk:
  - xvda: 50GB Mount: /
  - xvdb: 50GB Mount: /mnt/disk1
  - xvdc: 50GB Mount: /mnt/disk2
  - xvdd: 50GB Mount: /mnt/disk3

## Security groups
To be able to access to the EC2 VM, Grafana and Minio, it is necessary to create some security group rules:
- SSH
  - Type: SSH
  - Port: 22
- Grafana
  - Protocol: Custom TCP
  - Port: 3010
- Minio
  - Type: Custom TCP
  - Port: 9010

## How to create the instance
Prerequisites: AWS cli
How to install AWS cli: [link](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
In your laptop, configure AWS variables:
```
export AWS_ACCESS_KEY_ID="<your-key-id>"
export AWS_SECRET_ACCESS_KEY="<your-secret-access-key>"
export AWS_SESSION_TOKEN="<your-token>"
```
And execute this script:
```
./create_EC2_stack.sh
```

## Cleanup EC2 environment
```
./delete_EC2_stack.sh
```

## Admin users
### Installation
This software will be installed:
- Docker
- k3d
- kubectl
- helm
- bat
- htop
- cmclt
- rich

Connect to the AWS and check the security group. Make sure your 
IP address is included in the security group:
```
./admin/get_external_ip.sh 
xxx.xxx.xxx.xxx
```
Connect to the EC2 instance to install the software:
```
ssh -i "<your_pem_key>.pem" ec2-user@<your_instance>.compute.amazonaws.com
```
Or execute:
```
./connect_ec2.sh
```

And with `ec2_user` user, clone this project in the machine:
```
sudo dnf install -y git
git clone https://github.com/sergioenterprisedb/workshop-k8s.git
```

With `ec2-user`user:
```
cd ~/workshop-k8s/admin/
./install_EC2.sh
```
### Install minio
Execute:
```
cd ~/workshop-k8s/admin/minio
./install_minio.sh
```
After installation, you can access to MinIO with:
- User: `admin`
- Password: `password`
- URL: `http://<ec2_public_ip>:9010/`

![MinIO](./images/minio.jpg)

### Install Prometheus and Grafana
Execute:
```
cd ~/workshop-k8s/admin/prometheus
./install_prometheus.sh
```
After installation, you can access to MinIO with:
- User: `admin`
- Password: `prom-operator`
- URL: `http://<ec2_public_ip>:3010/login`

Install CloudNativePG dashboard:
- In Grafana, go to Dashboards -> New -> Import
- Import this [CloudnativePG Grafana dashboard file](https://github.com/cloudnative-pg/grafana-dashboards/blob/main/charts/cluster/grafana-dashboard.json)
- Load dashboard
- DS_PROMETHEUS: Select a prometheus data source: Prometheus
- Import

A new dashboard CloudNativePG is loaded.

![Grafana](./images/grafana.jpg)


### Install Shellinabox
Shell In A Box implements a web server that can export arbitrary command line tools to a web based terminal emulator. This emulator is accessible to any JavaScript and CSS enabled web browser and does not require any additional browser plugins.
```
cd ~/workshop-k8s/admin/shellinabox
./install_shellinabox.sh
```
Verify the connection to the environment:
- URL: `http://<your_EC2_ip>:4200`

### Create linux users
By default, 10 users are created in the Linux VM. The file `config.sh` contain the configuration:
```
cd ~/workshop-k8s/admin/
sudo ./create_linux_users.sh
```
### Postgres cluster tasks
The workshop admin have to connect with ec2-user and exeute these commands:
```
cd ~/workshop-k8s/user0/cnpg-hands-on/

./01_install_plugin.sh
./02_install_operator.sh
./03_check_operator_installed.sh
./04_install_barman_plugin.sh
```

### Admin task list
- [ ] Install EC2 VM
- [ ] Install Minio
- [ ] Prometheus/Grafana
- [ ] Shellinabox
- [ ] Create Linux users
- [ ] Kubernetes Plugin install
- [ ] Operator install
- [ ] Barman plugin install

## DBA users
The users (user1, user2, etc) have to connect to the VM. How to connect?
- With Shellinabox: `http://<your_EC2_ip>:4200`
- With ssh: `ssh -i "workshop-key.pem" ec2-user@ec2-xxx-xxx-xxx-xxx.<aws-region>.compute.amazonaws.com`
- User: `user[1..N]`
- Password: `password[1..N]`

And execute these commands to test the features:
```
./06_get_cluster_config_file.sh
./07_install_cluster.sh
./08_show_status.sh
./09_insert_data.sh
./10_backup_cluster.sh
./11_backup_describe.sh
./12_restore_cluster.sh
./13_check_restore.sh
./14_promote.sh
./15_failover.sh
./16_minor_upgrade.sh
./18_scale_out.sh
./19_scale_down.sh
./20_fencing.sh
./21_hibernation.sh
./22_major_upgrade_by_copy.sh
./23_verify_data_migrated.sh
./24_major_upgrade_in_place.sh
./25_verify_major_upgrade.sh
```

### DBA users task list
- [ ] Install Postgres cluster
- [ ] Insert data
- [ ] Show Postgres cluster status
- [ ] Backup Postgres cluster
- [ ] Restore Postgres cluster
- [ ] Promote
- [ ] Failover
- [ ] Minor Postgres cluster upgrade
- [ ] Postgres cluster scale out
- [ ] Postgres cluster scale down
- [ ] Fencing
- [ ] Hibernation
- [ ] Mayor Postgres cluster upgrade by copy
- [ ] Mayor Postgres cluster upgrade in place
