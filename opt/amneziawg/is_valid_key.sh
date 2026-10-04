#!/bin/bash
set -eEu -o pipefail

# Script must run as group 'vyattacfg' to prevent errors and system instability
if [ "$(id -g -n)" != 'vyattacfg' ] ; then
    echo "This script must be executed from vyatta configuration system."
    exit 1
fi

# Create variable for parameter
KEY=$1
# If KEY references a file, then read file into KEY
[ -e "$KEY" ] && KEY=$(cat $KEY)
# If KEY matches regular expression for 44 byte base64 string
[[ "$KEY" =~ ^[0-9a-zA-Z/+]{43}=$ ]]
# Exit with boolean results from test
exit $?
