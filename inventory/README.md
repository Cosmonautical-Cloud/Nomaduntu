# Inventory File Guide for Nomaduntu

This document explains how to structure your Ansible inventory file (`hosts.yml`) when deploying services using `playbooks/nomaduntu.yml`.

## Key Concepts

### Datacenter derivation

The **group name** each host belongs to becomes its Nomad **and** (by default) its Consul **datacenter** — both derived automatically from `group_names` at runtime, via the `facts` role. Every host in the `jellify` group defaults to the `jellify` datacenter, and so on.

### Servers vs. clients

Hosts with `server: { enabled: true }` form this group's own Nomad/Consul control plane. All other hosts are enrolled as client nodes that schedule and run workloads. `bootstrap_expect` is set automatically based on how many `server.enabled: true` hosts exist in this run's inventory.

### Joining an existing external cluster

If this inventory group has no `server.enabled: true` hosts of its own (e.g. a Semaphore run that only targets Ubuntu hosts, with the real Consul/Nomad servers living in a separate Ansible project such as Nomadintosh), set two optional variables — typically in `all.vars`, a Semaphore variable group, or `--extra-vars`:

| Variable | Effect |
|---|---|
| `existing_consul_datacenter` | Fixes Consul's `datacenter` to this value instead of deriving it from the group name. Nomad's own `datacenter` is unaffected — it's always the group name, since it's purely a job-placement tag. |
| `existing_cluster_servers` | A list of hostnames/IPs merged into `retry_join` for **both** Consul and Nomad, on top of whatever `server.enabled: true` hosts this run already found. |

Left unset, this inventory group bootstraps its own datacenter and control plane from its own `server.enabled: true` hosts, matching how Nomadintosh's own Consul role self-derives its datacenter. Setting both instead makes these hosts join an already-running external control plane under a fixed datacenter name — see `roles/consul/templates/consul.hcl.j2` for the exact precedence.

### `retry_join`

Both Nomad and Consul `retry_join` every host in this run's inventory that has `server.enabled: true`, plus `existing_cluster_servers` if set. You do not need to maintain this list by hand.

---

## Inventory Structure

```yaml
all:
  vars:
    # Applied to every host
    existing_consul_datacenter: cosmonautical   # optional
    existing_cluster_servers:                   # optional
      - cassiopeia.cosmonautical.cloud
      - taurus.cosmonautical.cloud
      - betelgeuse.cosmonautical.cloud

<datacenter-name>:
  hosts:
    <server1.example.com>:
      server:
        enabled: true
    <client1.example.com>:
      docker:
        enabled: true
```

Variables defined directly under a hostname override any group-level `vars` for that host.

---

## Supported Variables

### Connection variables (set under `all.vars` or per-group `vars`)

| Variable | Description |
|----------|-------------|
| `ansible_user` | SSH user for all hosts |
| `ansible_ssh_private_key_file` | Path to the SSH private key |
| `ansible_password` | SSH password (if not using key auth) |
| `ansible_become_password` | `sudo` password |
| `additional_apt_packages` | List of extra APT packages to install on every host |
| `existing_consul_datacenter` | Fixes Consul's datacenter instead of deriving it from the group name (see above) |
| `existing_cluster_servers` | Extra hosts merged into Consul's and Nomad's `retry_join` (see above) |

### Host variables (set per-host)

| Variable | Default | Description |
|----------|---------|-------------|
| `server.enabled` | `false` | Configures the host as a Nomad/Consul server node |
| `docker.enabled` | `false` | Installs Docker Engine and enables the Nomad `docker` plugin |
| `nfs_mounts_shares` | _(absent)_ | List of `{share_export_path}` NFS shares to mount (see below) |
| `volumes` | _(absent)_ | List of host volumes to expose to the Nomad client (see below) |

#### `nfs_mounts_shares` format

Each entry needs only `share_export_path`; the mount point is always `volume_mount_path` (`/mnt`) + `/<name>`, `<name>` being `share_export_path`'s final path component, lowercased. Not overridable per-share. Define it once under a group's `vars:` when every host in the group mounts the same shares, rather than repeating the list per host:

```yaml
nfs_mounts_shares:
  - share_export_path: /var/nfs/shared/Shared    # mounts at /mnt/shared
  - share_export_path: /var/nfs/shared/Jellify   # mounts at /mnt/jellify
```

#### `volumes` format

The `volumes` variable accepts a list of objects with `name` and `path` keys. Each entry is registered as a [Nomad host volume](https://developer.hashicorp.com/nomad/docs/configuration/client#host_volume) on the client:

```yaml
volumes:
  - name: Jellify
    path: /mnt/jellify
```

---

## Example Inventory

```yaml
all:
  vars:
    ansible_user: violet
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
    additional_apt_packages:
      - fastfetch
    # These hosts have no server.enabled: true of their own - join the
    # cosmonautical control plane that Nomadintosh already manages instead.
    existing_consul_datacenter: cosmonautical
    existing_cluster_servers:
      - cassiopeia.cosmonautical.cloud
      - taurus.cosmonautical.cloud
      - betelgeuse.cosmonautical.cloud

jellify:
  vars:
    nfs_mounts_shares:
      - share_export_path: /var/nfs/shared/Jellify
  hosts:
    kepler.jellify.app:
      docker:
        enabled: true
      volumes:
        - name: Jellify
          path: /mnt/jellify
```

In this example, `kepler` is a Nomad client only (no `server.enabled`) in the `jellify` Nomad datacenter, but its Consul agent joins the existing `cosmonautical` Consul datacenter/servers instead of bootstrapping an isolated one of its own.
