################################################################################
#
# amneziawg-linux-compat
#
################################################################################

AMNEZIAWG_LINUX_COMPAT_VERSION = PACKAGE_VERSION
AMNEZIAWG_LINUX_COMPAT_SITE = $(TOPDIR)/package/amneziawg-linux-compat
AMNEZIAWG_LINUX_COMPAT_SITE_METHOD = file
AMNEZIAWG_LINUX_COMPAT_SOURCE = amneziawg-linux-compat-$(AMNEZIAWG_LINUX_COMPAT_VERSION).tar
AMNEZIAWG_LINUX_COMPAT_LICENSE = GPL-2.0
AMNEZIAWG_LINUX_COMPAT_LICENSE_FILES = COPYING
AMNEZIAWG_LINUX_COMPAT_MODULE_SUBDIRS = src

define AMNEZIAWG_LINUX_COMPAT_LINUX_CONFIG_FIXUPS
	$(call KCONFIG_ENABLE_OPT,CONFIG_INET)
	$(call KCONFIG_ENABLE_OPT,CONFIG_NET)
	$(call KCONFIG_ENABLE_OPT,CONFIG_NET_FOU)
	$(call KCONFIG_ENABLE_OPT,CONFIG_CRYPTO)
	$(call KCONFIG_ENABLE_OPT,CONFIG_CRYPTO_MANAGER)
endef

$(eval $(kernel-module))
$(eval $(generic-package))
