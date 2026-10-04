Amnezia-WG for Ubiquiti
======================

Amnezia-WG (WireGuard with added privacy and obfuscation) for EdgeRouter, Unifi Gateway and Unifi Dream Machine

This package provides **Amnezia WireGuard** - a modified version of WireGuard with additional obfuscation features.
It runs **alongside** the standard WireGuard without interfering with it.

## Key Features

- **Independent from WireGuard**: Uses `awg` command and `awg0` interface naming
- **AmneziaWG 3.x obfuscation**: junk packets (Jc, Jmin, Jmax), paddings (S1-S4),
  header ranges (H1-H4), special junk packets (I1-I5), header protection,
  random trailers and tunable protocol timers
- **No Interference**: Does not affect or replace the standard WireGuard installation
- **Full CLI Support**: Configure via `set interfaces amneziawg awg0` commands

For a full list of supported devices, please see the latest release at [releases](https://github.com/coffeegrind123/amneziawg-vyatta-ubnt/releases).

The installation instructions can be found in the Wiki:

- [EdgeOS / UGW](https://github.com/WireGuard/wireguard-vyatta-ubnt/wiki/EdgeOS-and-Unifi-Gateway)
- [UnifiOS](https://github.com/WireGuard/wireguard-vyatta-ubnt/wiki/UnifiOS-%28UDM%2C-UDR%2C-UXG%29)

## Configuration Example

```bash
generate vpn amneziawg private-key awg_private.key

configure
set interfaces amneziawg awg0 address 10.0.0.1/24
set interfaces amneziawg awg0 listen-port 51820
set interfaces amneziawg awg0 private-key /config/auth/awg_private.key

# Junk packet train sent before each handshake
set interfaces amneziawg awg0 jc 4
set interfaces amneziawg awg0 jmin 40
set interfaces amneziawg awg0 jmax 70

# Random padding in front of each message type
set interfaces amneziawg awg0 s1 52
set interfaces amneziawg awg0 s2 61
set interfaces amneziawg awg0 s3 24
set interfaces amneziawg awg0 s4 16

# Message type headers: a single value or a range, no overlaps
set interfaces amneziawg awg0 h1 1180380445-1180380545
set interfaces amneziawg awg0 h2 1350254170-1350254270
set interfaces amneziawg awg0 h3 2010436017-2010436117
set interfaces amneziawg awg0 h4 905372881-905372981

# Special junk packets, built from tags
set interfaces amneziawg awg0 i1 '<b 0xc700000001><r 32><t>'
set interfaces amneziawg awg0 i2 '<b 0xf6ab3267fa><c><b 0xf6ab><t><r 10>'

# Header protection (needs s1-s4 of at least 12)
run generate vpn amneziawg header-protection-key awg_hpk.key
set interfaces amneziawg awg0 header-protection-key /config/auth/awg_hpk.key

# Peer
set interfaces amneziawg awg0 peer <public-key> allowed-ips 10.0.0.2/32
set interfaces amneziawg awg0 peer <public-key> endpoint 1.2.3.4:51820
set interfaces amneziawg awg0 peer <public-key> persistent-keepalive 25
commit
```

Both ends of a tunnel must use identical obfuscation values. Deleting a parameter
restores the AmneziaWG default for it.

## Parameters

| Option | Value | Default | Notes |
|--------|-------|---------|-------|
| `jc` | 0-65535 | 0 | Junk packets before each handshake; needs `jmax` |
| `jmin`, `jmax` | 0-65535 | 0 | Junk packet size bounds, `jmin` <= `jmax` |
| `s1`-`s4` | 0-65535 | 0 | Padding for initiation, response, cookie reply, transport data |
| `h1`-`h4` | `N` or `N-M`, 32-bit | 1-4 | Message type headers; must not overlap |
| `i1`-`i5` | tags | none | `<b 0xHEX>` bytes, `<r N>` random bytes, `<rc N>` letters, `<rd N>` digits, `<c>` counter, `<t>` timestamp |
| `header-protection-key` | key or file | none | Encrypts message headers; removing it recreates the interface |
| `content-padding-addition` | `N` or `N-M` | 0 | Extra random padding on transport data |
| `rekey-after-time` | `N` or `N-M` s | 120 | `0` keeps the default |
| `rekey-timeout` | `N` or `N-M` s | 5 | `0` keeps the default |
| `reject-after-time` | `N` or `N-M` s | 180 | `0` keeps the default |
| `keepalive-timeout` | `N` or `N-M` s | 10 | `0` keeps the default |
| `max-handshake-attempts` | `N` or `N-M` | 18 | `0` keeps the default |
| `random-trailers` | flag | off | Random-length trailers on packets |
| `disable-cookies` | flag | off | Never send cookie replies under load |
| `peer ... persistent-keepalive` | `N` or `N-M` s | 0 | `0` disables |

Ranges pick a random value from the range each time it is used.

## Operational Commands

- `show interfaces amneziawg [awgN] [allowed-ips|endpoints|latest-handshakes|transfer|...]`
- `show interfaces amneziawg awgN obfuscation` - all obfuscation parameters in effect
- `show interfaces amneziawg awgN configuration` - full `awg show` output
- `generate vpn amneziawg private-key|preshared-key|header-protection-key <file>`
- `clear interfaces amneziawg [awgN] counters`

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
| Obfuscation | No | Yes (see Parameters) |

## Building

CI builds every package (`.github/workflows/build.yml`). The kernel module source
is fetched and patched by `ci/prepare-module.sh` with the series in
`patches/amneziawg-linux-kernel-module/`; a patch that stops applying fails the
build. `Dockerfile.er4` reproduces the ER-4 build locally.

## Credits

Support for EdgeOS and Unifi Gateway was originally developed by [@Lochnair](https://github.com/Lochnair).
Support for UnifiOS was developed by [@tusc](https://github.com/tusc) and integrated into this repository by [@peacey](https://github.com/peacey).
See the [list of contributors](https://github.com/WireGuard/wireguard-vyatta-ubnt/graphs/contributors) and the [commit history](https://github.com/WireGuard/wireguard-vyatta-ubnt/commits/master) for the many other contributions.

Amnezia-WG support by [@coffeegrind123](https://github.com/coffeegrind123). The distinct
`amneziawg`/`awg` namespace, obfuscation-parameter CLI, kernel-compat fixes and WireGuard
coexistence packaging are derived from the [@paramosh](https://github.com/paramosh) fork.

Original AmneziaWG project: https://github.com/amnezia-vpn
