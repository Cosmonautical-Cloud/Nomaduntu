# nomad

Installs and configures [Nomad](https://developer.hashicorp.com/nomad/docs) as a systemd service on an Ubuntu host.

## What it does

1. Installs the `nomad` package via APT.
2. Creates the config (`nomad_config_dir`) and data (`nomad_working_dir`) directories.
3. Templates `nomad.hcl`, setting `datacenter` from the `facts` role's inventory-group-derived fact, joining any host marked `server.enabled: true` (plus `existing_cluster_servers`, if set, for joining an already-running external control plane), declaring any `volumes` as host volumes, and enabling the `docker` plugin when `docker.enabled: true`. Validates the rendered config with `nomad config validate` before applying it.
4. Registers Nomad as a systemd service, restarting it only when the package or config actually changed.

Requires the Hashicorp APT repository to already be configured on the host (see the `apt_repo` role).

## Requirements

- The `apt_repo` role must have run first to add the Hashicorp APT repository.
- The `facts` role must have run first to set the `datacenter` fact.
- Target host must be Debian/Ubuntu.
- Role must run with privilege escalation (`become: true`).

## Example

```yaml
- hosts: all
  become: true
  roles:
    - apt_repo
    - apt_update
    - nomad
```
