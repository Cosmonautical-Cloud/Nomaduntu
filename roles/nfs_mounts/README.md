# nfs_mounts

Mounts NFS shares on an Ubuntu host, typically to back Nomad host volumes.

## What it does

For each entry in `nfs_mounts_shares`, installs the `nfs-common` client package, creates the mount point, and mounts `{{ nas_host }}:{{ item.export }}` at `{{ item.mount_point }}` via `/etc/fstab` (using `ansible.posix.mount`, with `_netdev` so the mount waits for networking on boot). Opt-in per host — hosts with no `nfs_mounts_shares` defined get no NFS mounts.

## Defaults

| Variable | Default | Description |
|---|---|---|
| `nfs_mounts_shares` | `[]` | List of `{name, export, mount_point}` shares to mount |
| `nas_host` | `10.10.37.32` | NFS server address |
| `nfs_mounts_version` | `3` | NFS protocol version (the NAS only speaks NFSv3) |
| `nfs_mounts_rsize` / `nfs_mounts_wsize` | `65536` | Read/write buffer size |
| `nfs_mounts_timeo` | `100` | RPC timeout in tenths of a second before retransmit |
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
      - name: Shared
        export: /var/nfs/shared/Shared
        mount_point: /mnt/shared
  roles:
    - nfs_mounts
```
