# nfs_mounts

Mounts NFS shares on an Ubuntu host, typically to back Nomad host volumes.

## What it does

For each entry in `nfs_mounts_shares`, installs the `nfs-common` client package, creates the mount point, and mounts `{{ nas_host }}:{{ item.export }}` at `{{ item.mount_point }}` via `/etc/fstab` (using `ansible.posix.mount`, with `_netdev` so the mount waits for networking on boot). Opt-in per host — hosts with no `nfs_mounts_shares` defined get no NFS mounts.

`mount_point` is optional on each share entry — when omitted, it defaults to `{{ nfs_mounts_default_dir }}/<name>` (e.g. a share named `Jellify` with no `mount_point` lands at `/mnt/Jellify`), so a share can be added from an inventory source that only supplies `{name, export}` (e.g. a Semaphore variable group) without also spelling out the mount path every time.

## Defaults

| Variable | Default | Description |
|---|---|---|
| `nfs_mounts_shares` | `[]` | List of `{name, export, mount_point?}` shares to mount — `mount_point` is optional, see above |
| `nfs_mounts_default_dir` | `/mnt` | Parent directory used to build a share's mount point when it omits `mount_point` |
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
      # Explicit mount_point, honored as-is:
      - name: Shared
        export: /var/nfs/shared/Shared
        mount_point: /mnt/shared
      # No mount_point - defaults to /mnt/Jellify:
      - name: Jellify
        export: /var/nfs/shared/Jellify
  roles:
    - nfs_mounts
```
