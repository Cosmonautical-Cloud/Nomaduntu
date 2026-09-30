# consul

Installs and configures [Consul](https://developer.hashicorp.com/consul/docs) as a systemd service on an Ubuntu host.

## What it does

1. Installs the `consul` package via APT.
2. Creates the config (`consul_config_dir`) and data (`consul_working_dir`) directories, owned by the `consul` user.
3. Templates `consul.hcl`, joining any host in the inventory marked `server.enabled: true` under a datacenter derived from the inventory group name — or, if `existing_consul_datacenter` / `existing_cluster_servers` are set, joining an already-running external control plane under that fixed datacenter instead. Validates the rendered config with `consul validate` before applying it.
4. Registers Consul as a systemd service, restarting it only when the package or config actually changed.

Requires the Hashicorp APT repository to already be configured on the host (see the `apt_repo` role).

## Requirements

- The `apt_repo` role must have run first to add the Hashicorp APT repository.
- Target host must be Debian/Ubuntu.
- Role must run with privilege escalation (`become: true`).

## Example

```yaml
- hosts: all
  become: true
  roles:
    - apt_repo
    - apt_update
    - consul
```
