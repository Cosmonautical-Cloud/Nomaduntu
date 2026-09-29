# docker

Installs Docker Engine on an Ubuntu host so Nomad can run containerised jobs via its `docker` plugin.

## What it does

1. Installs `docker.io` via APT.
2. Enables and starts the `docker` systemd service.
3. Adds `ansible_user` to the `docker` group, as a manual debugging convenience (Nomad itself talks to the Docker socket as root via `become`).

## Requirements

- Target host must be Debian/Ubuntu.
- Role must run with privilege escalation (`become: true`).

## Example

```yaml
- hosts: all
  become: true
  roles:
    - docker
```
