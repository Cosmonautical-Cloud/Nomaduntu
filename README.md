# Nomaduntu

<img src="logo.png" alt="Nomaduntu Logo" width="200" height="225"  />

An Ansible playbook for deploying [Nomad](https://developer.hashicorp.com/nomad/docs) + [Consul](https://developer.hashicorp.com/consul/docs) on an Ubuntu cluster.

**[Nomad](https://developer.hashicorp.com/nomad/docs)** is a workload orchestrator by HashiCorp. It schedules and runs containerised and bare-metal applications across a cluster of machines, similar in spirit to Kubernetes but simpler to operate.

**[Consul](https://developer.hashicorp.com/consul/docs)** is a service mesh and service discovery tool, also by HashiCorp. It provides a distributed key-value store, health checking, and DNS-based service discovery. Nomad integrates with Consul natively to handle cluster membership and service registration.

## Scope

This playbook (like its [Nomadintosh](https://github.com/anultravioletaurora/Nomadintosh) counterpart and the [Nomadable](https://github.com/anultravioletaurora/Nomadable) parent that composes them) provisions the Nomad + Consul **agents** themselves — it does not deploy the job specs those agents run. Job specs live in dedicated repos: [`Jellify/Nomad-Jobs`](https://github.com/anultravioletaurora/Nomad-Jobs) (Terraform-managed) and a legacy hand-deployed `nomad-jobs` repo.

## Requirements

- Ansible installed on the control machine
- Target hosts running Ubuntu (22.04 LTS or later)
- SSH access to all hosts in the inventory

## Inventory

Hosts are organised into named groups; the group name becomes the Consul/Nomad [**datacenter**](https://developer.hashicorp.com/consul/docs/reference/agent/configuration-file/general#datacenter) for every host in that group.

**Host variables:**

| Variable | Values | Purpose |
|---|---|---|
| `server.enabled` | `true` / _(absent)_ | Configures the host as a Nomad/Consul server |
| `docker.enabled` | `true` / _(absent)_ | Installs Docker Engine and enables the Nomad `docker` plugin |
| `nfs_mounts_shares` | list of `{share_export_path}` | NFS shares to mount from `nas_host` (see `roles/nfs_mounts/defaults/main.yml`). Mount point is always `volume_mount_path` (`/mnt`) + `/<name>`, `<name>` being `share_export_path`'s final path component, lowercased |
| `volumes` | list of `{name, path}` | Nomad host volumes to declare in `client { }`, typically pointed at an `nfs_mounts_shares` mount point |

Example host definition:

```yaml
node1.example.com:
  server:
    enabled: true

node2.example.com:
  docker:
    enabled: true
  nfs_mounts_shares:
    - share_export_path: /var/nfs/shared/Shared    # mounts at /mnt/shared
    - share_export_path: /var/nfs/shared/Jellify   # mounts at /mnt/jellify
  volumes:
    - name: Shared
      path: /mnt/shared
    - name: Jellify
      path: /mnt/jellify

node3.example.com: {}
```

Nomad's `datacenter` is always derived from the host's inventory group name and is purely a job-placement tag. Consul's `datacenter` defaults to that same group name too, and this inventory group bootstraps its own Consul/Nomad control plane from its own `server.enabled: true` hosts — unless you set `existing_consul_datacenter` and `existing_cluster_servers` (e.g. via Semaphore variable groups or extra-vars), in which case these hosts instead join an already-running external control plane (such as one managed by a separate Ansible project) under that fixed datacenter name.

## Running the playbook

Run a full deployment:

```zsh
ansible-playbook -i inventory/hosts.yml playbooks/nomaduntu.yml
```

To limit execution to a single host or group:

```zsh
ansible-playbook -i inventory/hosts.yml playbooks/nomaduntu.yml --limit <hostname>
```

## What it does

For every host, the playbook performs the following steps:

1. **Facts** — asserts the host is running Ubuntu and sets the `datacenter` fact derived from the host's inventory group name.
2. **APT repository/update** — adds the HashiCorp apt repository and updates/upgrades packages.
3. **Docker** _(optional, `docker.enabled: true`)_ — installs Docker Engine, enables the service, and adds `ansible_user` to the `docker` group.
4. **NFS mounts** _(optional, `nfs_mounts_shares`)_ — mounts NFS shares from `nas_host` at the given mount points via `/etc/fstab`.
5. **Consul** — creates config/data directories, installs Consul via the HashiCorp apt repository, templates [`consul.hcl`](https://developer.hashicorp.com/consul/docs/reference/agent/configuration-file) with datacenter, node name, server/client mode, and [`retry_join`](https://developer.hashicorp.com/consul/docs/reference/agent/configuration-file/general#retry_join) derived from inventory, validates it, and registers a systemd service.
6. **Nomad** — creates config/data directories, installs Nomad via the HashiCorp apt repository, templates [`nomad.hcl`](https://developer.hashicorp.com/nomad/docs/configuration) (including [`bootstrap_expect`](https://developer.hashicorp.com/nomad/docs/configuration/server#bootstrap_expect), [`retry_join`](https://developer.hashicorp.com/nomad/docs/configuration/server_join), the `docker` plugin when enabled, and any declared `volumes` as host volumes), validates it, and registers a systemd service running as the non-root `nomad` user (see `roles/nomad/README.md`).

Services are managed as systemd units (Nomad and Consul), and are only restarted when their config, package, or (Nomad only) data directory permissions/user override actually changed.

## Remarks

- **Platform** — This playbook is tested against Ubuntu 24.04 LTS. Other Ubuntu versions may work but are untested.
- **Companion project** — [Nomadintosh](https://github.com/anultravioletaurora/Nomadintosh) is the macOS counterpart to this playbook. Nomad's multi-platform support means both clusters can participate in the same datacenter if desired.
- **Parent project** — [Nomadable](https://github.com/anultravioletaurora/Nomadable) composes this playbook with Nomadintosh into one deployment, dispatching each inventory host to the right child playbook by OS so a single mixed macOS/Ubuntu cluster can be deployed in one run. This is the actual deploy path in practice — running this repo's own `ansible-playbook`/`deploy.zsh` standalone (as described above) still works for Ubuntu-only changes, but Nomadable is what's normally invoked.
