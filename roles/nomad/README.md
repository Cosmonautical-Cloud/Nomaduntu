# nomad

Installs and configures [Nomad](https://developer.hashicorp.com/nomad/docs) as a systemd service on an Ubuntu host.

## What it does

1. Installs the `nomad` package via APT.
2. Creates the config (`nomad_config_dir`) and data (`nomad_working_dir`) directories.
3. Templates `nomad.hcl`, setting `datacenter` from the `facts` role's inventory-group-derived fact, joining any host marked `server.enabled: true` (plus `existing_cluster_servers`, if set, for joining an already-running external control plane), declaring any `volumes` as host volumes, and enabling the `docker` plugin when `docker.enabled: true`. Validates the rendered config with `nomad config validate` before applying it.
4. Registers Nomad as a systemd service, restarting it only when the package, config, data directory permissions, or the user override below actually changed.

Requires the Hashicorp APT repository to already be configured on the host (see the `apt_repo` role).

## Running as a non-root user

The `nomad` package's own systemd unit ships `User=root`/`Group=root`, with a
comment explaining that Nomad *clients* (unlike servers) need root for things
like cgroups/chroot setup (the `exec` driver) and bridge networking. This
role overrides that with a systemd drop-in to run as the dedicated `nomad`
system user instead (created by the package itself), matching how the
`consul` role already runs non-root and how Nomadintosh's macOS agents run as
the login user rather than root. `nomad_working_dir` is owned by `nomad` (not
`root`), and the `nomad` user is added to the `docker` group when
`docker.enabled: true` so the `docker` plugin keeps working.

This is a deliberate deviation from upstream's default advice for the
*client* role, safe here specifically because this collection only ever
configures the `raw_exec` and `docker` drivers - neither needs root. If a job
ever needs the `exec` driver, bridge networking, or to bind a port below
1024, this override needs revisiting first.

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
