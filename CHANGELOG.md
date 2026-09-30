# Changelog

All notable changes to this project are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project follows [semantic versioning](https://semver.org/).

## [1.2.0] - 2026-09-29

### Changed

- `config_dir` and `working_dir` now live in `playbooks/group_vars/all.yml` instead of a top-level `defaults/main.yml`. The latter is only auto-loaded by Ansible for actual roles, not a playbook-run repo like this one, so both variables were silently undefined; `nomad_config_dir`/`consul_config_dir` etc. would have failed to template on any real run. `playbooks/group_vars/all.yml` loads regardless of what inventory source is used to run the playbook, which also means the repo no longer depends on `inventory/hosts.yml` existing (e.g. when Semaphore supplies its own inventory).
- `existing_cluster_servers` and `existing_consul_datacenter` are now optional. Previously `consul.hcl.j2`/`nomad.hcl.j2` required both to be set (with no default anywhere in the repo, since the `inventory/group_vars/all.yml` their own comments pointed at didn't exist), so any run would fail on an undefined variable unless something outside the repo supplied them. Left unset, this inventory group now bootstraps its own datacenter and control plane from its own `server.enabled: true` hosts, matching how Nomadintosh's Consul role already self-derives its datacenter. Setting both still lets a group join an already-running external control plane instead.

### Fixed

- `additional_apt_packages` is now guarded with `| default([])` in the `apt_update` role (and defaults to `[]`), so a host that doesn't set it no longer fails with an undefined-variable error.

## [1.1.2] and earlier

Not tracked in this changelog. See `git log`.
