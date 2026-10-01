# clean

Runs `apt autoremove` on the host.

## What it does

1. Runs `apt autoremove` via `ansible.builtin.apt`, removing packages that were installed as dependencies but are no longer needed by anything currently installed (e.g. leftovers from a prior kernel/package upgrade).

## Usage

This role is used by the `playbooks/clean.yml` playbook, invoked via `./clean.zsh`.

```bash
./clean.zsh
```

## No manual setup required

No configuration is needed.
