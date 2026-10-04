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
PEER=$3

VYATTA_API=${vyatta_sbindir}/my_cli_shell_api
VYATTA_API_SLUG="interfaces amneziawg $INTERFACE peer $PEER"
alias node_exists='$VYATTA_API exists $VYATTA_API_SLUG'
alias node_value='$VYATTA_API returnValue $VYATTA_API_SLUG'
alias node_values='$VYATTA_API returnValues $VYATTA_API_SLUG'

function cfg_allowed-ips() {
    # If allowed-ips has values, create variable with values
    node_exists allowed-ips && ALLOWED=$(node_values allowed-ips | tr ' ' ',' | tr -d "'")
    # Set list of allowed-ips for peer
    sudo awg set $INTERFACE peer $PEER allowed-ips "${ALLOWED:-}"
    # Update routing table
    /opt/amneziawg/update_routes.sh "$INTERFACE"
}
function cfg_disable() {
    # If disable is deleted
    if [ "$ACTION" = DELETE ]; then
        # Add peer
        sudo awg set $INTERFACE peer $PEER

        # Prevent further delete operations
        ACTION=SET
        # Setup peer
        cfg_allowed-ips
        cfg_endpoint
        cfg_persistent-keepalive
        cfg_preshared-key
    # If disable is set
    elif [ "$ACTION" = SET ]; then
        # Remove peer
        sudo awg set $INTERFACE peer $PEER remove
        # Update routing table
        /opt/amneziawg/update_routes.sh "$INTERFACE"
    fi
}
function cfg_endpoint() {
    # If endpoint is deleted
    if [ "$ACTION" = DELETE ]; then
        # Remove peer
        sudo awg set $INTERFACE peer $PEER remove
        # Add peer
        sudo awg set $INTERFACE peer $PEER

        # Setup peer
        cfg_allowed-ips
        cfg_persistent-keepalive
        cfg_preshared-key
    # If endpoint has value and peer is not disabled
    elif node_exists endpoint && ! node_exists disable; then
        # Set endpoint
        sudo awg set $INTERFACE peer $PEER endpoint "$(node_value endpoint)"
    fi
}
function cfg_persistent-keepalive() {
    # If persistent-keepalive has value
    if node_exists persistent-keepalive; then
        # Set persistent-keepalive
        sudo awg set $INTERFACE peer $PEER persistent-keepalive $(node_value persistent-keepalive)
    else
        # Remove persistent-keepalive
        sudo awg set $INTERFACE peer $PEER persistent-keepalive 0
    fi
}
function cfg_preshared-key() {
    # If preshared-key has value
    if node_exists preshared-key; then
        # Create variable for preshared-key value
        PRESHARED_KEY=$(node_value preshared-key)
        # If preshared-key is a file
        if [ -f "$PRESHARED_KEY" ]; then
            # Set preshared-key to file
            sudo awg set $INTERFACE peer $PEER preshared-key $PRESHARED_KEY
        else
            # Set preshared-key to value
            echo $PRESHARED_KEY | sudo awg set $INTERFACE peer $PEER preshared-key /proc/self/fd/0
        fi
    else
        # Remove preshared-key
        sudo awg set $INTERFACE peer $PEER preshared-key /dev/null
    fi
}

# AmneziaWG specific peer parameters
function cfg_jc() {
    if node_exists jc; then
        sudo awg set $INTERFACE peer $PEER jc $(node_value jc)
    fi
}

function cfg_jmin() {
    if node_exists jmin; then
        sudo awg set $INTERFACE peer $PEER jmin $(node_value jmin)
    fi
}

function cfg_jmax() {
    if node_exists jmax; then
        sudo awg set $INTERFACE peer $PEER jmax $(node_value jmax)
    fi
}

function cfg_s1() {
    if node_exists s1; then
        sudo awg set $INTERFACE peer $PEER s1 $(node_value s1)
    fi
}

function cfg_s2() {
    if node_exists s2; then
        sudo awg set $INTERFACE peer $PEER s2 $(node_value s2)
    fi
}

function cfg_h1() {
    if node_exists h1; then
        sudo awg set $INTERFACE peer $PEER h1 $(node_value h1)
    fi
}

function cfg_h2() {
    if node_exists h2; then
        sudo awg set $INTERFACE peer $PEER h2 $(node_value h2)
    fi
}

function cfg_h3() {
    if node_exists h3; then
        sudo awg set $INTERFACE peer $PEER h3 $(node_value h3)
    fi
}

function cfg_h4() {
    if node_exists h4; then
        sudo awg set $INTERFACE peer $PEER h4 $(node_value h4)
    fi
}

## Peer option configuration
# If more than three parameters are passed to this script
if [ $# -gt 3 ]; then
    # If function exists in script, then run the function
    type cfg_$4 2> /dev/null | grep -q 'function' && eval "cfg_$4 ${5:-}"
    # Do not process the rest of the script
    exit
fi

## Main peer configuration
# If peer is deleted or disable is true
if [ "$ACTION" = DELETE ] || node_exists disable; then
    # If peer exists in list of peers
    if [[ $(sudo awg show "$INTERFACE" peers) == *"$PEER"* ]]; then
        # Remove peer
        sudo awg set $INTERFACE peer $PEER remove
    fi
else
    # Add peer
    sudo awg set $INTERFACE peer $PEER
fi
