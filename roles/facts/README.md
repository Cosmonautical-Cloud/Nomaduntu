# facts

Sets the `datacenter` fact used by the `nomad` and `consul` roles.

## What it does

Derives `datacenter` from the host's inventory group name (the first group that isn't `all` or `ungrouped`) and sets it as a fact. This is purely a Nomad job-placement tag — Consul's own datacenter is derived independently in `consul.hcl.j2` (defaulting to the same group name, or `existing_consul_datacenter` when set) and does not use this fact.

## Requirements

- Each host must belong to exactly one meaningful inventory group (besides `all`/`ungrouped`).

## Example

```yaml
- hosts: all
  roles:
    - facts
```
