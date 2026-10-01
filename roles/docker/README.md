# docker

Installs Docker Engine on an Ubuntu host so Nomad can run containerised jobs via its `docker` plugin, based on `docker.enabled`.

## What it does

`docker.enabled: true` (`tasks/setup.yml`):

1. Installs `docker.io` via APT.
2. Enables and starts the `docker` systemd service.
3. Adds `ansible_user` to the `docker` group, as a manual debugging convenience (Nomad itself talks to the Docker socket as root via `become`).

`docker.enabled: false` (`tasks/teardown.yml`): uninstalls `docker.io` via APT. Removing the package stops and disables the systemd service as part of its own removal, so there's no separate stop/disable step here. `ansible_user`'s membership in the `docker` group is left alone — it's a debugging convenience, not a deployed artifact, and not worth the risk of an `ansible.builtin.user` call that could disturb the account's other group memberships.

`docker` absent entirely — this role isn't included at all (see `playbooks/deploy.yml`); a host that's never mentioned `docker` is left alone either way. Matches the `is defined`/`| default(false)` split Nomadintosh's `docker_desktop`/`podman`/`container` roles use.

## Host variables

| Variable | Values | Effect |
|---|---|---|
| `docker.enabled` | `true` / `false` / _(absent)_ | Install, uninstall, or don't manage Docker Engine on this host |

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
