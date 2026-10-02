# Inventory File Guide for Nomaduntu

This document explains how to structure your Ansible inventory file (`hosts.yml`) when deploying services using `playbooks/deploy.yml`.

## Key Concepts

### Datacenter derivation

The Nomad and Consul **datacenters come from DNS**, not from inventory groups — no variable to set (the `facts` role resolves them):

- **Nomad datacenter** = the host's second-to-last DNS label: `euler.jellify.app` → `jellify`.
- **Consul datacenter** = that same label taken from the Consul servers (`server.enabled: true` hosts), which must all share one domain. A Consul datacenter is a separate cluster with its own servers, so a client in another domain still joins the servers' datacenter. With no servers in the inventory, it's this host's own label — unless `existing_consul_datacenter` (below) is set.

So **every inventory host must be listed by its fully qualified name** (`host.<datacenter>.<tld>`) — the run fails up front otherwise. Use `ansible_host` to connect by IP.

### Inventory groups

Groups are freeform — a host can be in any number, across datacenters. Every Nomad client publishes its groups as node meta (`inventory_groups = "game_servers,jellify"`), so a job can target one with:

```hcl
constraint {
  attribute = "${meta.inventory_groups}"
  operator  = "set_contains"
  value     = "game_servers"
}
```

`nomad_client_meta` (a dict, merged with any `nomad_client_meta__<suffix>` dicts) adds extra keys. `additional_apt_packages` is likewise merged with any `additional_apt_packages__<suffix>` lists, so a group can add packages without repeating the `all`-level list.

### Servers vs. clients

Hosts with `server: { enabled: true }` form this group's own Nomad/Consul control plane. All other hosts are enrolled as client nodes that schedule and run workloads. `bootstrap_expect` is set automatically based on how many `server.enabled: true` hosts exist in this run's inventory.

### Joining an existing external cluster

If this inventory group has no `server.enabled: true` hosts of its own (e.g. a Semaphore run that only targets Ubuntu hosts, with the real Consul/Nomad servers living in a separate Ansible project such as Nomadintosh), set two optional variables — typically in `all.vars`, a Semaphore variable group, or `--extra-vars`:

| Variable | Effect |
|---|---|
| `existing_consul_datacenter` | Fixes Consul's `datacenter` to this value instead of deriving it from the servers' domain. Nomad's own `datacenter` is unaffected — it's always this host's own domain label. |
| `existing_cluster_servers` | A list of hostnames/IPs merged into `retry_join` for **both** Consul and Nomad, on top of whatever `server.enabled: true` hosts this run already found. |

Left unset, the datacenter comes from the inventory's `server.enabled: true` hosts' domain, matching Nomadintosh. Setting both instead makes these hosts join an already-running external control plane under a fixed datacenter name — see `roles/consul/templates/consul.hcl.j2` for the exact precedence.

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
| `additional_apt_packages` | List of extra APT packages to install on every host. Merged with any `additional_apt_packages__<suffix>` lists |
| `nomad_client_meta` | Dict of extra Nomad client `meta` keys. Merged with any `nomad_client_meta__<suffix>` dicts |
| `existing_consul_datacenter` | Fixes Consul's datacenter instead of deriving it from the servers' domain (see above) |
| `existing_cluster_servers` | Extra hosts merged into Consul's and Nomad's `retry_join` (see above) |
| `nas_host` | Address of the NFS server `nfs_mounts_shares` are mounted from. **Required** if any host sets `nfs_mounts_shares` — no default |

### Host variables (set per-host)

| Variable | Default | Description |
|----------|---------|-------------|
| `server.enabled` | `false` | Configures the host as a Nomad/Consul server node |
| `docker.enabled` | _(absent)_ | `true` installs Docker Engine and enables the Nomad `docker` plugin; `false` actively removes Docker Engine; absent leaves the host unmanaged either way (see `roles/docker/README.md`) |
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
