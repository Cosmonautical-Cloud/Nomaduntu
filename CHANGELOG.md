# Changelog

All notable changes to this project are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project follows [semantic versioning](https://semver.org/).

## [5.0.0] - 2026-10-02

### Breaking

- **Datacenters come from DNS instead of inventory group names.** A host's Nomad datacenter is its second-to-last DNS label (`euler.jellify.app` → `jellify`). Consul's is `existing_consul_datacenter` if set, else the label shared by the inventory's `server.enabled` hosts, else this host's own label — previously it defaulted to the host's own *group name*, so a client-only run with servers in the same inventory but a different group bootstrapped the wrong datacenter unless `existing_consul_datacenter` was set. The `facts` role now runs first on every deploy, tagged `always`, and fails on hosts not listed by fully qualified name or on Consul servers spanning more than one domain. Matches Nomadintosh 5.0.0. Inventory groups are now free for roles and Nomad meta; a host in several groups no longer risks landing in the wrong datacenter (the old rule took the first group alphabetically).

### Added

- `nomad`: every client publishes its inventory groups as node meta `inventory_groups` (comma-separated, excluding `all`/`ungrouped`/the playbook's own `os_*` groups), so jobs can target any inventory group with a `set_contains` constraint. `nomad_client_meta` adds extra keys. **Changes `nomad.hcl` on every host**, so the first deploy rolling-restarts every Nomad agent.
- `additional_apt_packages` and `nomad_client_meta` are merged with every `<name>__<suffix>` variable visible to the host, so a group can add to the `all`-level value without repeating it. Same convention as Nomadintosh.

### Fixed

- `playbooks/deploy.yml`: `--tags` runs did nothing. The OS-discovery `group_by` task had no tags, so any `--tags` run skipped it and the deployment play matched no hosts; it's now tagged `always`. The role includes also didn't `apply` their tags to the included tasks, so even with discovery fixed, e.g. `--tags nomad` skipped every Nomad task.

## [4.0.0] - 2026-10-02

### Breaking

- `nas_host` no longer has a default. It used to be hardcoded to `10.10.37.32` in `roles/nfs_mounts/defaults/main.yml`, but it's site-specific, so it now has to be set in your own inventory (`group_vars`/`host_vars`) or as an extra var (e.g. Semaphore variables). The `nfs_mounts` role asserts it's set, before changing anything, on any host with a non-empty `nfs_mounts_shares`; hosts without shares are unaffected.

### Changed

- `consul`/`nomad`: restarts after a config/package (and, for Nomad, data-directory permission, user-override, or docker-group) change now roll one host at a time instead of firing on every host in parallel — same behavior as Nomadintosh 4.0.0. Each host's flag is recorded (`consul_restart_needed`/`nomad_restart_needed`), then the first play host loops over the flagged ones, delegating a `systemd` restart to each and waiting for it to report healthy before moving on — Consul: `/v1/status/leader` non-empty, then `/v1/operator/autopilot/health` `Healthy`; Nomad: `/v1/agent/health`, then `/v1/operator/autopilot/health` `Healthy`. A host that never gets healthy within `*_restart_retries` × `*_restart_delay` (default 36 × 5s) fails the whole run (`any_errors_fatal`). "Ensure … is running" now runs before the restart decision, and a service it just started isn't restarted again.

## [3.2.1] - 2026-10-01

### Fixed

CI's `ansible-lint` job was failing — this repo had no `.ansible-lint` config at all (unlike Nomadintosh's), so it ran under a different, more exhaustive ruleset. Brought it in line with Nomadintosh's deliberate `profile: moderate` config and fixed the resulting violations:

- New `.ansible-lint`: `profile: moderate`, `exclude_paths: [.github/]` (fixes 5 `yaml[document-start]` failures on `.github/*` files that were never meant to be linted as Ansible content).
- `roles/*/meta/main.yml` (all 10 roles): added `galaxy_info.min_ansible_version: "2.15"`, the required property `schema[meta]` was failing on.
- `galaxy.yml`: added the `linux` tag — `galaxy[tags]` requires at least one tag from a fixed allowed set; none of the existing tags qualified.
- `meta/runtime.yml`: `requires_ansible: ">=2.15"` → `">=2.15.0"` — `meta-runtime[unsupported-version]` requires a full major.minor.patch version.
- `roles/nfs_mounts/tasks/main.yml`: wrapped the NFS `opts` line (176 chars) under `yaml[line-length]`'s 160-character limit using a YAML double-quoted backslash line-continuation — verified the rendered value is byte-for-byte identical to the original (no behavior change; `ansible.posix.mount` sees the exact same `opts` string).

### Changed

- `.ansible-lint`: `var-naming[no-role-prefix]` added to `skip_list` (same reasoning as Nomadintosh — `nas_host`, `additional_apt_packages`, `volume_mount_path` are public inventory variables the user sets directly; renaming would break existing inventories) and `no-handler` added to `warn_list` (the "Dearmor Hashicorp GPG Key" task in `roles/apt_repo/tasks/main.yml` can't be a real handler — the very next task needs the dearmored keyring immediately, not deferred to end-of-play).

## [3.2.0] - 2026-10-01

### Changed

- **Breaking (behavioral):** `docker.enabled: false` now actively uninstalls Docker Engine (`roles/docker/tasks/teardown.yml`), instead of being a no-op. The `playbooks/deploy.yml` gate changed from `when: docker.enabled | default(false)` (role skipped entirely unless `true`) to `when: docker.enabled is defined` (role runs whenever the var is set at all, and branches internally on the real boolean), matching Nomadintosh's `docker_desktop`/`podman`/`container` roles. Previously, flipping a host from `true` to `false` left Docker Engine installed and running with no way to remove it through this role. If any host currently relies on `docker.enabled: false` being inert, it will now have Docker Engine removed on the next run — audit inventory before upgrading. `docker.enabled` left absent entirely is still fully unmanaged, as before.

### Docs

- `roles/docker/README.md` and `inventory/README.md` updated for the install/uninstall/absent split above.
- Fixed stale `anultravioletaurora/Nomadintosh` and `anultravioletaurora/Nomadable` links in `README.md` — both repos moved to the `Cosmonautical-Cloud` GitHub org (see 2.0.0 below); this repo's own README cross-links to them were never updated to match.

## [3.1.0] - 2026-10-01

### Added

- New `clean` role and `playbooks/clean.yml` — runs `apt autoremove` to prune packages left behind by upgrades that nothing else depends on anymore. Added `clean.zsh` wrapper to match the existing scripts. `Nomadable`'s own `playbooks/clean.yml` (added alongside this) composes this with Nomadintosh's equivalent.

### Fixed

- **`playbooks/deploy.yml`, `playbooks/reboot.yml`, `playbooks/clean.yml`**: OS filtering moved from a `when: ansible_facts['os_family'] == 'Debian'` block condition to the play level, via a `group_by` discovery play that sorts hosts into `os_Darwin`/`os_Debian` dynamic groups before the real work play runs against `hosts: os_Debian`. This fixes a real bug in `reboot.yml` and `clean.yml`: against a mixed inventory (the normal case when invoked through `Nomadable`, which passes one shared inventory to both child playbooks), the old `hosts: all` plus unconditional task made every host - including macOS ones - get hit a second time once `Nomadable`'s copy of this playbook also ran Nomadintosh's version against the same hosts. `deploy.yml` was already safely gated behind a single block-level `when:` and didn't double-run, but now uses the same idiom as the other playbooks for consistency.

## [3.0.0] - 2026-10-01

### Added

- New `reboot` role and `playbooks/reboot.yml`, matching Nomadintosh's — reboots every host in the inventory one at a time (`serial: 1`, `ansible.builtin.reboot`, 5-minute timeout). This repo had no equivalent before; `Nomadable`'s own `playbooks/reboot.yml` (added alongside this) now composes both OS's reboot playbooks. Added `reboot.zsh` wrapper to match the existing `deploy.zsh`/`check.zsh` scripts.

### Changed

- **Breaking:** `playbooks/nomaduntu.yml` renamed to `playbooks/deploy.yml`. Anything invoking it by filename (`ansible-playbook playbooks/nomaduntu.yml`, `deploy.zsh`/`check.zsh`/`lint.zsh`) or by FQCN (`ansible.builtin.import_playbook: cosmonautical.nomaduntu.nomaduntu`, used by `Nomadable`, bumped alongside this) needs updating to `playbooks/deploy.yml` / `cosmonautical.nomaduntu.deploy`.

### Fixed

- `check.zsh`'s comment said "Run Nomadintosh in check mode" — copy-paste leftover, fixed to say Nomaduntu.

- `.github/workflows/lint.yml`'s syntax-check step ran `ansible-playbook playbooks/nomadintosh.yml` — a copy-paste leftover from Nomadintosh's own workflow that pointed at a file that's never existed in this repo. Fixed to the actual playbook (now `playbooks/deploy.yml`).

## [2.0.1] - 2026-10-01

### Docs

- Added a `## Playbooks` section to the README naming `playbooks/nomaduntu.yml` with a one-line description, matching the same addition in Nomadintosh. Ansible Galaxy has no synopsis field for playbook content at all (confirmed via `galaxy_importer`'s `PlaybookLoader`, which never sets a `description` the way `RoleLoader` does from `meta/main.yml`) — every role here already has one via its own `meta/main.yml`, so this closes the equivalent gap for the one playbook that doesn't get that treatment.

## [2.0.0] - 2026-10-01

### Changed

- **Breaking:** Galaxy namespace moved from the personal `anultravioletaurora` to the now-approved `cosmonautical` namespace (same one `cosmonautical.notify` already publishes under). The collection's fully-qualified name is now `cosmonautical.nomaduntu` instead of `anultravioletaurora.nomaduntu` — anything installing or importing it (including the `Nomadable` playbook, bumped alongside this) needs its `collections/requirements.yml` pin and `import_playbook`/role references updated to match. The GitHub repo location (`Cosmonautical-Cloud/Nomaduntu`) is unchanged; this is purely the Galaxy identity. Previously published `anultravioletaurora.nomaduntu` versions are left in place on Galaxy, just no longer the publish target.

## [1.3.5] - 2026-09-30

### Changed

- Removed the hard dependency on `cosmonautical.notify` (from `galaxy.yml` and `collections/requirements.yml`) while the `cosmonautical` Galaxy namespace is still pending approval and the collection isn't publishable yet. No call site was wired in here yet (see Nomadintosh for the `include_tasks` + `notify_enabled` scaffold pattern used there), so this is just the dependency removal — add `cosmonautical.notify` back once it's live on Galaxy.

## [1.3.4] - 2026-09-30

### Docs

- Repo moved from `anultravioletaurora/nomaduntu` to the `Cosmonautical-Cloud` GitHub org. Updated `repository`/`homepage`/`issues` in `galaxy.yml` to match. Galaxy namespace (`anultravioletaurora`) is unaffected — it's tied to the Galaxy account, not the repo's GitHub location.

## [1.3.3] - 2026-09-30

### Added

- Depends on the shared [`cosmonautical.notify`](https://github.com/Cosmonautical-Cloud/ansible-collection-notify) collection, the same Discord-webhook module (`cosmonautical.notify.discord`) Nomadintosh uses. No task in this playbook calls it yet — it's available for a future notification call site rather than wired in now. The local `inventory/hosts.yml` `notifications: [{type, url}]` var is renamed `discord_webhooks: [{id, token}]` to match the module's expected args, ahead of that.

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
