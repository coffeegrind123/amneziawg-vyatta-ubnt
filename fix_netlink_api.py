#!/usr/bin/env python3
"""
Script to fix AmnesiaWG netlink.c API compatibility issues for older UBNT kernels
"""

import sys
import os

def fix_netlink_api():
    netlink_file = "src/netlink.c"
    
    if not os.path.exists(netlink_file):
        print(f"Error: {netlink_file} not found")
        return False
        
    # Read the file
    with open(netlink_file, 'r') as f:
        content = f.read()
    
    # Fix 1: Replace get_random_u8() with compatibility code
    old_get_random = '\t\t\taddr[prefix_bytes] |= get_random_u8() & ~mask;'
    new_get_random = '''#if LINUX_VERSION_CODE >= KERNEL_VERSION(4,11,0)
\t\t\taddr[prefix_bytes] |= get_random_u8() & ~mask;
#else
\t\t\tu8 random_byte;
\t\t\tget_random_bytes(&random_byte, 1);
\t\t\taddr[prefix_bytes] |= random_byte & ~mask;
#endif'''
    
    content = content.replace(old_get_random, new_get_random)
    
    # Fix 2: Add compatibility wrapper around mcgrps fields
    old_mcgrps = '\t.mcgrps = wg_genl_mcgrps,\n\t.n_mcgrps = ARRAY_SIZE(wg_genl_mcgrps)'
    new_mcgrps = '''#if LINUX_VERSION_CODE >= KERNEL_VERSION(3,13,0)
\t.mcgrps = wg_genl_mcgrps,
\t.n_mcgrps = ARRAY_SIZE(wg_genl_mcgrps)
#endif'''
    
    content = content.replace(old_mcgrps, new_mcgrps)
    
    # Fix 3: Add compatibility wrapper around genlmsg_multicast_netns
    old_multicast = '\tret = genlmsg_multicast_netns(&genl_family, dev_net(wg->dev), skb, 0, 0, GFP_KERNEL);'
    new_multicast = '''#if LINUX_VERSION_CODE >= KERNEL_VERSION(3,13,0)
\tret = genlmsg_multicast_netns(&genl_family, dev_net(wg->dev), skb, 0, 0, GFP_KERNEL);
#else
\tret = genlmsg_multicast(skb, 0, 0, GFP_KERNEL);
#endif'''
    
    content = content.replace(old_multicast, new_multicast)
    
    # Write the file back
    with open(netlink_file, 'w') as f:
        f.write(content)
        
    print("Applied netlink API compatibility fixes successfully")
    return True

if __name__ == "__main__":
    success = fix_netlink_api()
    sys.exit(0 if success else 1)