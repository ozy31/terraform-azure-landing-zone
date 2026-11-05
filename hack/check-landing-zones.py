#!/usr/bin/env python3
"""Checks across landing-zones/*.yaml that Terraform cannot express easily:
connected address spaces are inside the spoke supernet and do not overlap
each other or the hub, and corp firewall priorities are unique."""
import ipaddress
import pathlib
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
# Keep in sync with terraform/envs/platform/variables.tf.
HUB = ipaddress.ip_network("10.100.0.0/22")
SUPERNET = ipaddress.ip_network("10.0.0.0/10")

errors = []
connected = {}
priorities = {}

for path in sorted((ROOT / "landing-zones").glob("*.yaml")):
    name = path.stem
    lz = yaml.safe_load(path.read_text())
    net = ipaddress.ip_network(lz["addressSpace"])
    if lz["archetype"] not in ("corp", "online"):
        continue
    if not net.subnet_of(SUPERNET):
        errors.append(f"{name}: {net} is outside the spoke supernet {SUPERNET}")
    if net.overlaps(HUB):
        errors.append(f"{name}: {net} overlaps the hub {HUB}")
    for other, other_net in connected.items():
        if net.overlaps(other_net):
            errors.append(f"{name}: {net} overlaps {other} ({other_net})")
    connected[name] = net
    if lz["archetype"] == "corp":
        prio = lz.get("firewallPriority")
        if prio is None:
            errors.append(f"{name}: corp landing zones need a firewallPriority")
        elif prio in priorities:
            errors.append(f"{name}: firewallPriority {prio} is already used by {priorities[prio]}")
        else:
            priorities[prio] = name

for e in errors:
    print(f"ERROR {e}", file=sys.stderr)
print(f"{len(connected)} connected landing zones checked, {len(errors)} errors")
sys.exit(1 if errors else 0)
