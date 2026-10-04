#!/bin/bash
# Validation for AmneziaWG configuration templates.
#
#   validate.sh range <value> <max>   N or N-M, with N <= M <= max
#   validate.sh ispec <value>         I1-I5 special junk packet tags
#   validate.sh interface <awgN>      cross-parameter rules at commit
#
# The kernel enforces the same rules, but only when 'awg set' runs halfway
# through a commit, which leaves the interface partially configured. Catching
# them here rejects the commit before anything is applied.
set -Eu -o pipefail

HEADER_PROTECTION_MIN_PADDING=12    # HEADER_PROTECTION_NONCE_SIZE in the module
U16_MAX=65535
U32_MAX=4294967295

function fail {
    echo "$*"
    exit 1
}

# Echo "lo hi" for a range string, or fail
function parse_range {
    local value=$1 max=$2 lo hi

    if [[ ! "$value" =~ ^([0-9]{1,10})(-([0-9]{1,10}))?$ ]]; then
        fail "'$value' is not a number or a range (N-M)"
    fi
    lo=$((10#${BASH_REMATCH[1]}))
    hi=$((10#${BASH_REMATCH[3]:-${BASH_REMATCH[1]}}))
    if [ $lo -gt $hi ]; then
        fail "Range '$value' has its start above its end"
    fi
    if [ $hi -gt $max ]; then
        fail "'$value' exceeds the maximum of $max"
    fi
    echo "$lo $hi"
}

# Tag grammar from jp_parse_tags() in the kernel module: tags are separated
# by exactly one space from their argument, and anything outside <...> is
# ignored by the kernel, so only whitespace is allowed between tags here.
function check_ispec {
    local value=$1
    local tag='<(b 0x([0-9a-fA-F]{2})+|c|t|(r|rc|rd) [0-9]{1,5})>'

    if [[ ! "$value" =~ ^[[:space:]]*(${tag}[[:space:]]*)+$ ]]; then
        fail "'$value' is not a valid special junk packet. Use tags: <b 0xHEX> <r N> <rc N> <rd N> <c> <t>"
    fi
}

function node_exists {
    "${vyatta_sbindir}/my_cli_shell_api" exists interfaces amneziawg "$INTERFACE" "$@"
}

function value_or {
    if node_exists "$1"; then
        "${vyatta_sbindir}/my_cli_shell_api" returnValue interfaces amneziawg "$INTERFACE" "$1"
    else
        echo "$2"
    fi
}

function check_interface {
    local intf=$INTERFACE
    local jc jmin jmax i j name range
    local -a lo hi

    jc=$(value_or jc 0)
    jmin=$(value_or jmin 0)
    jmax=$(value_or jmax 0)
    # The kernel only sends junk when both jc and jmax are set
    if [ "$jc" -gt 0 ] && [ "$jmax" -gt 0 ] && [ "$jmin" -gt "$jmax" ]; then
        fail "$intf: jmin ($jmin) must not be greater than jmax ($jmax)"
    fi

    # Unset headers keep the WireGuard message types 1-4
    for i in 1 2 3 4; do
        range=$(parse_range "$(value_or h$i $i)" $U32_MAX) || fail "$intf: h$i: $range"
        lo[$i]=${range% *}
        hi[$i]=${range#* }
    done
    for i in 1 2 3 4; do
        for j in $(seq $((i + 1)) 4); do
            if [ ${lo[$i]} -le ${hi[$j]} ] && [ ${lo[$j]} -le ${hi[$i]} ]; then
                fail "$intf: h$i and h$j overlap; header values must be unique"
            fi
        done
    done

    if node_exists header-protection-key; then
        for name in s1 s2 s3 s4; do
            if [ "$(value_or $name 0)" -lt $HEADER_PROTECTION_MIN_PADDING ]; then
                fail "$intf: $name must be at least $HEADER_PROTECTION_MIN_PADDING when header-protection-key is set"
            fi
        done
    fi
}

case "${1:-}" in
    range)
        range=$(parse_range "${2:-}" "${3:-$U16_MAX}") || fail "$range"
        ;;
    ispec)
        check_ispec "${2:-}"
        ;;
    interface)
        INTERFACE=${2:?interface name required}
        check_interface
        ;;
    *)
        fail "usage: $0 range <value> [max] | ispec <value> | interface <awgN>"
        ;;
esac
