# consul

Installs and configures [Consul](https://developer.hashicorp.com/consul/docs) as a systemd service on an Ubuntu host.

## What it does

1. Installs the `consul` package via APT.
2. Creates the config (`consul_config_dir`) and data (`consul_working_dir`) directories, owned by the `consul` user.
3. Templates `consul.hcl`, joining any host in the inventory marked `server.enabled: true` under a datacenter derived from the inventory group name — or, if `existing_consul_datacenter` / `existing_cluster_servers` are set, joining an already-running external control plane under that fixed datacenter instead. Validates the rendered config with `consul validate` before applying it.
4. Registers Consul as a systemd service, restarting it only when the package or config actually changed. Restarts roll one host at a time: after each one, the run waits for that agent to see a raft leader and for `/v1/operator/autopilot/health` to report healthy (up to `consul_restart_retries` × `consul_restart_delay` seconds) before restarting the next, and stops the whole run if it never does — so it never takes more than one server out of quorum at once.

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
