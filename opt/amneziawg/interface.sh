#!/bin/bash
set -eEu -o pipefail
shopt -s expand_aliases

# Script must run as group 'vyattacfg' to prevent errors and system instability
if [ "$(id -g -n)" != 'vyattacfg' ] ; then
    echo "This script must be executed from vyatta configuration system."
    exit 1
fi

ACTION=$1
INTERFACE=$2

VYATTA_API=${vyatta_sbindir}/my_cli_shell_api
VYATTA_API_SLUG="interfaces amneziawg $INTERFACE"
alias node_exists='$VYATTA_API exists $VYATTA_API_SLUG'
alias node_list='$VYATTA_API listNodes $VYATTA_API_SLUG'
alias node_value='$VYATTA_API returnValue $VYATTA_API_SLUG'
alias node_values='$VYATTA_API returnValues $VYATTA_API_SLUG'

function cfg_address {
    # If address is deleted
    if [ "$ACTION" = DELETE ]; then
        OP=delete
    else
        OP=add
    fi
    # Parse all IP address on interface
    for ip in $(ip a show dev $INTERFACE | grep inet | awk '{print $2}'); do
        # If adding IP address to the interface and IP address is already setup on interface
        if [ $OP == "add" ] && [ $ip == "$1" ]; then
            # Do not process the rest of the function
            return
        fi
    done
    # Execute operation on link
    sudo /opt/vyatta/sbin/vyatta-address $OP $INTERFACE $1
}
function cfg_description {
    # If description has value
    if node_exists description; then
        # Set link alias
        ip link set dev $INTERFACE alias "$(node_value description)"
    else
        # Remove link alias
        sudo sh -c "echo > /sys/class/net/$INTERFACE/ifalias"
    fi
}
function cfg_fwmark {
    # If fwmark has value
    if node_exists fwmark; then
        # Mark packets leaving this interface
        sudo awg set $INTERFACE fwmark $(node_value fwmark)
    else
        # Do not mark packets leaving this interface
        sudo awg set $INTERFACE fwmark 0
    fi
}
function cfg_listen-port {
    # If listen-port has value
    if node_exists listen-port; then
        # Set listen-port
        sudo awg set $INTERFACE listen-port $(node_value listen-port)
    else
        # Set listen-port to random port
        sudo awg set $INTERFACE listen-port 0
    fi
}
function cfg_mtu {
    # If mtu has value
    if node_exists mtu; then
        # Set link MTU
        ip link set $INTERFACE mtu $(node_value mtu)
    fi
}
function cfg_private-key {
    # If private-key has value
    if node_exists private-key; then
        # Set private-key from file or value
        set_key private-key private-key
    else
        # Remove private-key
        sudo awg set $INTERFACE private-key /dev/null
    fi
}
function cfg_route-allowed-ips {
    # Update routing table
    /opt/amneziawg/update_routes.sh $INTERFACE
}

# Write an awg key (inline base64 or a file path) to the given awg set option
function set_key {
    KEY=$(node_value "$1")
    if [ -f "$KEY" ]; then
        sudo awg set $INTERFACE "$2" "$KEY"
    else
        echo "$KEY" | sudo awg set $INTERFACE "$2" /proc/self/fd/0
    fi
}
# Print a node's value, or the AmneziaWG default when the node is unset.
# Sending the default on delete is what reverts a removed setting in the
# kernel; skipping unset nodes would leave the old value live.
function value_or {
    if node_exists "$1"; then
        node_value "$1"
    else
        echo "$2"
    fi
}
function flag {
    if node_exists "$1"; then
        echo on
    else
        echo off
    fi
}

# AmneziaWG obfuscation parameters
#
# Grouped settings go to the kernel in one netlink message, because it
# validates each value against the others in the same message:
#   jc/jmin/jmax   - junk packet train
#   h1-h4          - ranges must not overlap; set one at a time, a commit
#                    that swaps two values would fail halfway
#   s1-s4 + key    - with header protection, every padding must be >= 12
function cfg_junk {
    sudo awg set $INTERFACE \
        jc "$(value_or jc 0)" \
        jmin "$(value_or jmin 0)" \
        jmax "$(value_or jmax 0)"
}
function cfg_headers {
    sudo awg set $INTERFACE \
        h1 "$(value_or h1 1)" \
        h2 "$(value_or h2 2)" \
        h3 "$(value_or h3 3)" \
        h4 "$(value_or h4 4)"
}
function cfg_padding {
    # The kernel can enable header protection but never disable it again;
    # dropping the key needs a fresh link
    if [ -z "${REBUILT:-}" ] && ! node_exists header-protection-key && kernel_has_header_protection; then
        rebuild_interface
        return
    fi
    ARGS=(
        s1 "$(value_or s1 0)"
        s2 "$(value_or s2 0)"
        s3 "$(value_or s3 0)"
        s4 "$(value_or s4 0)"
    )
    if ! node_exists header-protection-key; then
        sudo awg set $INTERFACE "${ARGS[@]}"
        return
    fi
    KEY=$(node_value header-protection-key)
    if [ -f "$KEY" ]; then
        sudo awg set $INTERFACE "${ARGS[@]}" header-protection-key "$KEY"
    else
        echo "$KEY" | sudo awg set $INTERFACE "${ARGS[@]}" header-protection-key /proc/self/fd/0
    fi
}
function kernel_has_header_protection {
    # Field 20 of the dump's interface line; 'awg show <if>
    # header-protection-key' prints a key even when none is set
    KEY=$(sudo awg show $INTERFACE dump | head -n 1 | cut -f 20)
    [ -n "$KEY" ] && [ "$KEY" != "(none)" ]
}
function cfg_special {
    sudo awg set $INTERFACE "$1" "$(value_or "$1" "")"
}

function cfg_jc { cfg_junk; }
function cfg_jmin { cfg_junk; }
function cfg_jmax { cfg_junk; }
function cfg_s1 { cfg_padding; }
function cfg_s2 { cfg_padding; }
function cfg_s3 { cfg_padding; }
function cfg_s4 { cfg_padding; }
function cfg_header-protection-key { cfg_padding; }
function cfg_h1 { cfg_headers; }
function cfg_h2 { cfg_headers; }
function cfg_h3 { cfg_headers; }
function cfg_h4 { cfg_headers; }
function cfg_i1 { cfg_special i1; }
function cfg_i2 { cfg_special i2; }
function cfg_i3 { cfg_special i3; }
function cfg_i4 { cfg_special i4; }
function cfg_i5 { cfg_special i5; }

# AmneziaWG 3.x protocol tuning; 0 selects the built-in default
function cfg_content-padding-addition {
    sudo awg set $INTERFACE content-padding-addition "$(value_or content-padding-addition 0)"
}
function cfg_rekey-after-time {
    sudo awg set $INTERFACE rekey-after-time "$(value_or rekey-after-time 0)"
}
function cfg_rekey-timeout {
    sudo awg set $INTERFACE rekey-timeout "$(value_or rekey-timeout 0)"
}
function cfg_reject-after-time {
    sudo awg set $INTERFACE reject-after-time "$(value_or reject-after-time 0)"
}
function cfg_keepalive-timeout {
    sudo awg set $INTERFACE keepalive-timeout "$(value_or keepalive-timeout 0)"
}
function cfg_max-handshake-attempts {
    sudo awg set $INTERFACE max-handshake-attempts "$(value_or max-handshake-attempts 0)"
}
function cfg_random-trailers {
    sudo awg set $INTERFACE random-trailers "$(flag random-trailers)"
}
function cfg_disable-cookies {
    sudo awg set $INTERFACE disable-cookies "$(flag disable-cookies)"
}

# Delete and recreate the link, then re-apply the whole configuration
function rebuild_interface {
    REBUILT=1
    eval "$(node_value down-command)" > /dev/null || exit 1
    sudo ip link del dev $INTERFACE
    sudo ip link add dev $INTERFACE type amneziawg

    ACTION=SET
    cfg_description
    cfg_mtu
    eval "ADDRESSES=($(node_values address))"
    for address in "${ADDRESSES[@]}"; do
        cfg_address "$address"
    done
    cfg_private-key
    cfg_listen-port
    if node_exists fwmark; then
        cfg_fwmark
    fi
    cfg_junk
    cfg_padding
    cfg_headers
    for i in i1 i2 i3 i4 i5; do
        cfg_special $i
    done
    cfg_content-padding-addition
    cfg_rekey-after-time
    cfg_rekey-timeout
    cfg_reject-after-time
    cfg_keepalive-timeout
    cfg_max-handshake-attempts
    cfg_random-trailers
    cfg_disable-cookies

    # Peers add routes, which needs the link up, as in the normal create path
    if ! node_exists disable; then
        sudo ip link set up dev $INTERFACE
    fi

    eval "PEERS=($(node_list peer))"
    for peer in "${PEERS[@]}"; do
        /opt/amneziawg/peer.sh SET $INTERFACE "$peer"
        if $VYATTA_API exists $VYATTA_API_SLUG peer "$peer" disable; then
            continue
        fi
        for option in allowed-ips endpoint persistent-keepalive preshared-key; do
            /opt/amneziawg/peer.sh SET $INTERFACE "$peer" $option
        done
    done

    if ! node_exists disable; then
        /opt/amneziawg/update_routes.sh "$INTERFACE"
        eval "$(node_value up-command) > /dev/null" || exit 1
    fi
}

## Interface option configuration
# If more than two parameters are passed to this script
if [ $# -gt 2 ]; then
    # Interface is being deleted; its link goes away with it
    if ! node_exists; then
        exit
    fi
    # If function exists in script, then run the function
    type cfg_$3 2> /dev/null | grep -q 'function' && eval "cfg_$3 ${4:-}"
    # Do not process the rest of the script
    exit
fi

## Main interface configuration
# If link doesn't exist
if ! ip link show dev $INTERFACE &> /dev/null; then
    # Create link using amneziawg
    sudo ip link add dev $INTERFACE type amneziawg
else
    # Run all configured 'down' commands
    eval "$(node_value down-command)" > /dev/null || exit 1
    # Disable link
    sudo ip link set down dev $INTERFACE
fi

# If interface is deleted
if [ "$ACTION" = DELETE ]; then
    # Delete link
    sudo ip link del dev $INTERFACE
    # Do not process the rest of the script
    exit
fi

# If disable is not set
if ! node_exists disable; then
    # Enable link
    sudo ip link set up dev $INTERFACE
    # Update routing table
    /opt/amneziawg/update_routes.sh "$INTERFACE"
    # Run all configured 'up' commands
    eval "$(node_value up-command) > /dev/null" || exit 1
fi
