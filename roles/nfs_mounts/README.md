# nfs_mounts

Mounts NFS shares on an Ubuntu host, typically to back Nomad host volumes.

## What it does

For each entry in `nfs_mounts_shares`, installs the `nfs-common` client package, creates the mount point, and mounts `{{ nas_host }}:{{ item.share_export_path }}` at the computed mount point via `/etc/fstab` (using `ansible.posix.mount`, with `_netdev` so the mount waits for networking on boot). Opt-in per host — hosts with no `nfs_mounts_shares` defined get no NFS mounts.

This is a plain fstab mount rather than a watchdog daemon like Nomadintosh's macOS role: Linux's own NFS client already retries per the `timeo`/`retrans` options below, and `_netdev` defers the mount until networking is up on boot, so a separate always-on watchdog isn't needed here the way it is to work around macOS's `mount_nfs` behavior.

## Configuration

Each `nfs_mounts_shares` entry only needs `share_export_path`; the mount point is always `volume_mount_path` (`/mnt`) + `/<name>`, with `<name>` being the final path component of `share_export_path`, lowercased (unlike Nomadintosh's macOS role, which keeps the name as-is to match the old SMB paths — there's no equivalent casing convention to match on Linux, and lowercase mount points are the more idiomatic default here). Not configurable per-share:

```yaml
nfs_mounts_shares:
  - share_export_path: /var/nfs/shared/Shared    # mounts at /mnt/shared
  - share_export_path: /var/nfs/shared/Jellify   # mounts at /mnt/jellify
```

## Defaults

| Variable | Default | Why |
|---|---|---|
| `nfs_mounts_shares` | `[]` | Opt-in per host — see above |
| `volume_mount_path` | `/mnt` | Parent directory every share mounts under — the conventional Linux mount root, mirroring Nomadintosh's `/Volumes` on the macOS side |
| `nas_host` | _(none — required)_ | The NFS server's address. Site-specific, so it must come from your inventory (`group_vars`/`host_vars`) or extra vars; the role fails before touching anything if a host has `nfs_mounts_shares` but no `nas_host` |
| `nfs_mounts_version` | `3` | The NAS only speaks NFSv3 (confirmed on the macOS side 2026-09-21, same NAS here) |
| `nfs_mounts_rsize` / `nfs_mounts_wsize` | `65536` | Read/write buffer size |
| `nfs_mounts_timeo` | `100` | RPC timeout in tenths of a second before retransmit — same tuning as the macOS mounts, raised from the kernel default of 7 (0.7s) so a slow-but-alive NAS under concurrent load doesn't get piled on with redundant retransmits |
| `nfs_mounts_retrans` | `3` | Number of retransmits before giving up |

## Requirements

- Target host must be Debian/Ubuntu.
- Role must run with privilege escalation (`become: true`).
- Requires the `ansible.posix` collection (see `collections/requirements.yml`).

## Example

```yaml
- hosts: all
  become: true
  vars:
    nfs_mounts_shares:
      - share_export_path: /var/nfs/shared/Shared
      - share_export_path: /var/nfs/shared/Jellify
  roles:
    - nfs_mounts
```
