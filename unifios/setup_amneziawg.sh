#!/bin/sh
# This script loads the amneziawg module and copies the amneziawg tools.
# The built-in kernel module will be loaded if it exists.
AMNEZIAWG="$(cd "$(dirname "$0")" && pwd -P)"

# create symlinks to amneziawg tools
ln -sf $AMNEZIAWG/tools/awg-quick /usr/bin
ln -sf $AMNEZIAWG/tools/awg /usr/bin
ln -sf $AMNEZIAWG/tools/qrencode /usr/bin
if [ ! -x "$(command -v bash)" ]; then
	ln -sf $AMNEZIAWG/tools/bash /bin
fi

# create symlink to amneziawg config folder
mkdir -p $AMNEZIAWG/etc/amneziawg
if [ ! -d "/etc/amneziawg" ]
then
   ln -sf $AMNEZIAWG/etc/amneziawg /etc/amneziawg
fi

# required by awg-quick
if [ ! -d "/dev/fd" ]
then
   ln -s /proc/self/fd /dev/fd
fi

#load dependent modules
modprobe udp_tunnel
modprobe ip6_udp_tunnel

lsmod|egrep ^amneziawg > /dev/null 2>&1
if [ $? -eq 1 ]
then
   ver=`uname -r`
   echo "loading amneziawg..."
   if [ -e /lib/modules/$ver/extra/amneziawg.ko ]; then
      modprobe amneziawg
   elif [ -e $AMNEZIAWG/modules/amneziawg-$ver.ko ]; then
     insmod $AMNEZIAWG/modules/amneziawg-$ver.ko
#    iptable_raw required for awg-quick's use of iptables-restore
     insmod $AMNEZIAWG/modules/iptable_raw-$ver.ko
     insmod $AMNEZIAWG/modules/ip6table_raw-$ver.ko
   else
     echo "Unsupported Kernel version $ver"
   fi
fi
