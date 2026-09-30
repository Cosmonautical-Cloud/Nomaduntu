# Changelog

All notable changes to this project are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project follows [semantic versioning](https://semver.org/).

## [1.3.3] - 2026-09-30

### Added

- Depends on the shared [`cosmonautical.notify`](https://github.com/Cosmonautical-Cloud/ansible-collection-notify) collection (`cosmonautical.notify.discord`), the same Discord-webhook role Nomadintosh uses. No task in this playbook calls it yet — it's available for a future notification call site rather than wired in now. The local `inventory/hosts.yml` `notifications: [{type, url}]` var is renamed `discord_webhooks: [{url}]` to match the role's own variable, ahead of that.

## [1.3.1] - 2026-09-29

### Changed

- **Breaking:** `nfs_mounts_shares` entries now take only `share_export_path` (renamed from `export`). `name` and `mount_point` are gone — the mount point is always `volume_mount_path` (renamed from `nfs_mounts_default_dir`, still `/mnt`) + `/<name>`, with `<name>` derived from `share_export_path`'s final path component and lowercased. Existing inventory entries need updating: `{name, export, mount_point?}` → `{share_export_path}`. Mirrors the same change in Nomadintosh, except Nomadintosh keeps the derived name's original casing (to match its SMB-migration paths) while this role lowercases it (no equivalent casing convention to match on Linux).

## [1.3.0] - 2026-09-29

### Added

- `nfs_mounts_shares` entries no longer require `mount_point`: it now defaults to `nfs_mounts_default_dir` (`/mnt`) + `/<name>` when omitted, so a share can be added from an inventory source that only supplies `{name, export}` (e.g. a Semaphore variable group) without also spelling out the mount path every time. Explicit `mount_point` values are unaffected.

### Changed

- The `nomad` role now runs the Nomad client as the non-root `nomad` system user instead of root, via a systemd drop-in overriding the package's own `User=root`/`Group=root` unit. `nomad_working_dir` is chowned to `nomad` (recursively, to fix up anything already created as root), and `nomad` is added to the `docker` group when `docker.enabled: true` so the `docker` driver keeps working. This matches how the `consul` role already runs non-root and how Nomadintosh's macOS agents run as the login user - discovered because a `raw_exec` job on this cluster was found running its Minecraft server as root with no `user` set, since nothing overrode the package's client-must-be-root default. Deliberately narrower than upstream's own advice: safe here only because this collection exclusively uses the `raw_exec` and `docker` drivers, neither of which needs root the way `exec` (chroot/cgroups) or bridge networking would. See `roles/nomad/README.md` for the tradeoff.

### Docs

- Rewrote `inventory/README.md`, which had been an unmodified copy of Nomadintosh's own inventory guide — it described Homebrew/`podman`/`container`/`minecraft`/`gh_actions` variables that don't exist in this repo, and never mentioned `nfs_mounts_shares`, `volumes`, or `existing_consul_datacenter`/`existing_cluster_servers` at all.

## [1.2.0] - 2026-09-29

### Changed

- `config_dir` and `working_dir` now live in `playbooks/group_vars/all.yml` instead of a top-level `defaults/main.yml`. The latter is only auto-loaded by Ansible for actual roles, not a playbook-run repo like this one, so both variables were silently undefined; `nomad_config_dir`/`consul_config_dir` etc. would have failed to template on any real run. `playbooks/group_vars/all.yml` loads regardless of what inventory source is used to run the playbook, which also means the repo no longer depends on `inventory/hosts.yml` existing (e.g. when Semaphore supplies its own inventory).
- `existing_cluster_servers` and `existing_consul_datacenter` are now optional. Previously `consul.hcl.j2`/`nomad.hcl.j2` required both to be set (with no default anywhere in the repo, since the `inventory/group_vars/all.yml` their own comments pointed at didn't exist), so any run would fail on an undefined variable unless something outside the repo supplied them. Left unset, this inventory group now bootstraps its own datacenter and control plane from its own `server.enabled: true` hosts, matching how Nomadintosh's Consul role already self-derives its datacenter. Setting both still lets a group join an already-running external control plane instead.

### Fixed

- `additional_apt_packages` is now guarded with `| default([])` in the `apt_update` role (and defaults to `[]`), so a host that doesn't set it no longer fails with an undefined-variable error.

## [1.1.2] and earlier

Not tracked in this changelog. See `git log`.
