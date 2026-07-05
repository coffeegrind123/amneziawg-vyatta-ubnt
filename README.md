Amnezia-WG for Ubiquiti
======================

Amnezia-WG (WireGuard with added privacy and obfuscation) for EdgeRouter, Unifi Gateway and Unifi Dream Machine

This package provides **Amnezia WireGuard** - a modified version of WireGuard with additional obfuscation features.
It runs **alongside** the standard WireGuard without interfering with it.

## Key Features

- **Independent from WireGuard**: Uses `awg` command and `awg0` interface naming
- **Obfuscation Support**: Includes AmneziaWG parameters (Jc, Jmin, Jmax, S1, S2, H1-H4)
- **No Interference**: Does not affect or replace the standard WireGuard installation
- **Full CLI Support**: Configure via `set interfaces amneziawg awg0` commands

For a full list of supported devices, please see the latest release at [releases](https://github.com/paramosh/amneziawg-vyatta-ubnt/releases).

The installation instructions can be found in the Wiki:

- [EdgeOS / UGW](https://github.com/WireGuard/wireguard-vyatta-ubnt/wiki/EdgeOS-and-Unifi-Gateway)
- [UnifiOS](https://github.com/WireGuard/wireguard-vyatta-ubnt/wiki/UnifiOS-%28UDM%2C-UDR%2C-UXG%29)

## Configuration Example

```bash
# Configure AmneziaWG interface
set interfaces amneziawg awg0 address 10.0.0.1/24
set interfaces amneziawg awg0 listen-port 51820
set interfaces amneziawg awg0 private-key /config/auth/awg_private.key

# AmneziaWG obfuscation parameters (Junk packets)
set interfaces amneziawg awg0 jc 3
set interfaces amneziawg awg0 jmin 1000
set interfaces amneziawg awg0 jmax 3000
set interfaces amneziawg awg0 s1 500
set interfaces amneziawg awg0 s2 1000

# AmneziaWG obfuscation parameters (Header junk packets)
set interfaces amneziawg awg0 h1 100
set interfaces amneziawg awg0 h2 200
set interfaces amneziawg awg0 h3 300
set interfaces amneziawg awg0 h4 400

# AmneziaWG obfuscation parameters (Init junk packets)
set interfaces amneziawg awg0 i1 50
set interfaces amneziawg awg0 i2 100
set interfaces amneziawg awg0 i3 150
set interfaces amneziawg awg0 i4 200
set interfaces amneziawg awg0 i5 250

# Configure peer
set interfaces amneziawg awg0 peer <public-key> allowed-ips 10.0.0.2/32
set interfaces amneziawg awg0 peer <public-key> endpoint 1.2.3.4:51820
```

## Command Line Tools

After installation, use the following commands:

- `awg` - AmneziaWG userspace control utility
- `awg-quick` - Simplified configuration tool

## Differences from WireGuard

| Feature | WireGuard | AmneziaWG |
|---------|-----------|-----------|
| Command | `wg` | `awg` |
| Interface | `wg0`, `wg1`, ... | `awg0`, `awg1`, ... |
| Config path | `/etc/wireguard` | `/etc/amneziawg` |
| Obfuscation | No | Yes (Jc, Jmin, Jmax, S1, S2, H1-H4, I1-I5) |

## Credits

Support for EdgeOS and Unifi Gateway was originally developed by [@Lochnair](https://github.com/Lochnair).
Support for UnifiOS was developed by [@tusc](https://github.com/tusc) and integrated into this repository by [@peacey](https://github.com/peacey).
See the [list of contributors](https://github.com/WireGuard/wireguard-vyatta-ubnt/graphs/contributors) and the [commit history](https://github.com/WireGuard/wireguard-vyatta-ubnt/commits/master) for the many other contributions.

Amnezia-WG support and modifications by [@paramosh](https://github.com/paramosh).

Original AmneziaWG project: https://github.com/amnezia-vpn
