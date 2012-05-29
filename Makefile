
#
# Mountain Gorilla Makefile. See "README.md".
#

#---- Config

include bits/config.mk

# Directories
TOP=$(shell pwd)
BITS_DIR=$(TOP)/bits

# Tools
MAKE = make
TAR = tar
UNAME := $(shell uname)
ifeq ($(UNAME), SunOS)
	MAKE = gmake
	TAR = gtar
endif
JSON=$(MG_NODE) $(TOP)/tools/json

# Other
# Is JOBS=16 reasonable here? The old bamboo plans used this (or higher).
JOB=16

# A TIMESTAMP to use must be defined (and typically is in 'bits/config.mk').
#
# At one point we'd just generate TIMESTAMP at the top of the Makefile, but
# that seemed to hit a gmake issue when building multiple targets: the 'ca'
# target would be run three times at (rougly) 4 seconds apart on the time
# stamp (guessing the 'three times' is because CA_BITS has three elements).
# Similarly for the 'agents' target.
ifeq ($(TIMESTAMP),)
	TIMESTAMP=TimestampNotSet
endif

ifeq ($(UPLOAD_LOCATION),)
	UPLOAD_LOCATION=stuff@stuff.joyent.us:builds
endif



#---- Primary targets

.PHONY: all
all: smartlogin amon ca agents agentsshar assets adminui portal mapi redis riak rabbitmq dhcpd webinfo billapi cloudapi workflow manatee cnapi zapi dapi napi dcapi platform moray ufds usbheadnode releasejson

.PHONY: all-except-platform
all-except-platform: smartlogin amon ca agents agentsshar assets adminui portal mapi redis riak rabbitmq dhcpd webinfo billapi cloudapi workflow manatee cnapi zapi dapi napi dcapi moray ufds usbheadnode releasejson


#---- smartlogin
# TODO:
# - Re-instate 'gmake lint'?

SMARTLOGIN_BITS=$(BITS_DIR)/smartlogin/smartlogin-$(SMART_LOGIN_BRANCH)-$(TIMESTAMP)-g$(SMART_LOGIN_SHA).tgz

.PHONY: smartlogin
smartlogin: $(SMARTLOGIN_BITS)

# PATH: ensure using GCC from SFW. Not sure this is necessary, but has been
# the case for release builds pre-MG.
$(SMARTLOGIN_BITS): build/smart-login
	@echo "# Build smartlogin: branch $(SMART_LOGIN_BRANCH), sha $(SMART_LOGIN_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/smart-login && TIMESTAMP=$(TIMESTAMP) PATH=/usr/sfw/bin:$(PATH) BITS_DIR=$(BITS_DIR) gmake clean all publish)
	@echo "# Created smartlogin bits:"
	@ls -1 $(SMARTLOGIN_BITS)
	@echo ""

clean_smartlogin:
	rm -rf $(BITS_DIR)/smartlogin



#---- agents

_a_stamp=$(AGENTS_BRANCH)-$(TIMESTAMP)-g$(AGENTS_SHA)
AGENTS_BITS=$(BITS_DIR)/agents/agents_core/agents_core-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/heartbeater/heartbeater-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/dataset_manager/dataset_manager-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/provisioner-v2/provisioner-v2-$(_a_stamp).tgz \
	$(BITS_DIR)/agents/zonetracker-v2/zonetracker-v2-$(_a_stamp).tgz
AGENTS_BITS_0=$(shell echo $(AGENTS_BITS) | awk '{print $$1}')

agents: $(AGENTS_BITS_0)

# PATH: ensure using GCC from SFW. Not sure this is necessary, but has been
# the case for release builds pre-MG.
$(AGENTS_BITS): build/agents
	@echo "# Build agents: branch $(AGENTS_BRANCH), sha $(AGENTS_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/agents && TIMESTAMP=$(TIMESTAMP) PATH=/usr/sfw/bin:$(PATH) ./build.sh -p -n -l $(BITS_DIR)/agents -L)
	@echo "# Created agents bits:"
	@ls -1 $(AGENTS_BITS)
	@echo ""

clean_agents:
	rm -rf $(BITS_DIR)/agents



#---- amon

_amon_stamp=$(AMON_BRANCH)-$(TIMESTAMP)-g$(AMON_SHA)
AMON_BITS=$(BITS_DIR)/amon/amon-pkg-$(_amon_stamp).tar.bz2 \
	$(BITS_DIR)/amon/amon-relay-$(_amon_stamp).tgz \
	$(BITS_DIR)/amon/amon-agent-$(_amon_stamp).tgz
AMON_BITS_0=$(shell echo $(AMON_BITS) | awk '{print $$1}')

.PHONY: amon
amon: $(AMON_BITS_0)

$(AMON_BITS): build/amon
	@echo "# Build amon: branch $(AMON_BRANCH), sha $(AMON_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/amon && IGNORE_DIRTY=1 TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake clean all pkg publish)
	@echo "# Created amon bits:"
	@ls -1 $(AMON_BITS)
	@echo ""

clean_amon:
	rm -rf $(BITS_DIR)/amon
	(cd build/amon && gmake clean)



#---- cloud-analytics
#TODO:
# - merge CA_VERSION and CA_PUBLISH_VERSION? what about the version sed'd into
#   the package.json's?
# - look at https://hub.joyent.com/wiki/display/dev/Setting+up+Cloud+Analytics+development+on+COAL-147
#   for env setup. Might be demons in there. (RELENG-192)

_ca_stamp=$(CLOUD_ANALYTICS_BRANCH)-$(TIMESTAMP)-g$(CLOUD_ANALYTICS_SHA)
CA_BITS=$(BITS_DIR)/ca/ca-pkg-$(_ca_stamp).tar.bz2 \
	$(BITS_DIR)/ca/cabase-$(_ca_stamp).tar.gz \
	$(BITS_DIR)/ca/cainstsvc-$(_ca_stamp).tar.gz
CA_BITS_0=$(shell echo $(CA_BITS) | awk '{print $$1}')

.PHONY: ca
ca: $(CA_BITS_0)

# PATH for ca build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
config_ca_old: build/cloud-analytics
	@echo "# Build ca: branch $(CLOUD_ANALYTICS_BRANCH), sha $(CLOUD_ANALYTICS_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/cloud-analytics && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) PATH="/sbin:/opt/local/bin:/usr/gnu/bin:/usr/bin:/usr/sbin:$(PATH)" gmake clean pkg release publish)
	@echo "# Created ca bits:"
	@ls -1 $(CA_BITS)
	@echo ""

#
# Build CA in the new build-zone style if requested by configure.
#
config_ca_new: build/cloud-analytics
	@echo "# Build ca: branch $(CLOUD_ANALYTICS_BRANCH), sha $(CLOUD_ANALYTICS_SHA)"
	mkdir -p $(BITS_DIR)
	TIMESTAMP=$(TIMESTAMP) BRANCH=$(BRANCH) $(TOP)/tools/build-zone build.json $(TOP)/targets.json ca $(CLOUD_ANALYTICS_SHA)
	@ls -1 $(CA_BITS)
	@echo ""

# Warning: if CA's submodule deps change, this 'clean_ca' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_ca:
	rm -rf $(BITS_DIR)/ca
	(cd build/cloud-analytics && gmake clean)



#---- UFDS

_ufds_stamp=$(UFDS_BRANCH)-$(TIMESTAMP)-g$(UFDS_SHA)
UFDS_BITS=$(BITS_DIR)/ufds/ufds-pkg-$(_ufds_stamp).tar.bz2

.PHONY: ufds
ufds: $(UFDS_BITS)

# PATH for ufds build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(UFDS_BITS): build/ufds
	@echo "# Build ufds: branch $(UFDS_BRANCH), sha $(UFDS_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/ufds && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created ufds bits:"
	@ls -1 $(UFDS_BITS)
	@echo ""

# Warning: if UFDS's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_ufds:
	rm -rf $(BITS_DIR)/ufds
	(cd build/ufds && gmake clean)

#---- BILLAPI

_billapi_stamp=$(BILLING_API_BRANCH)-$(TIMESTAMP)-g$(BILLING_API_SHA)
BILLAPI_BITS=$(BITS_DIR)/billapi/billapi-pkg-$(_billapi_stamp).tar.bz2

.PHONY: billapi
billapi: $(BILLAPI_BITS)

# PATH for ufds build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(BILLAPI_BITS): build/billing_api
	@echo "# Build billapi: branch $(BILLING_API_BRANCH), sha $(BILLING_API_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/billing_api && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created billapi bits:"
	@ls -1 $(BILLAPI_BITS)
	@echo ""

# Warning: if billapi's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_billapi:
	rm -rf $(BITS_DIR)/billapi
	(cd build/billapi && gmake clean)

#---- ASSETS

_assets_stamp=$(ASSETS_BRANCH)-$(TIMESTAMP)-g$(ASSETS_SHA)
ASSETS_BITS=$(BITS_DIR)/assets/assets-pkg-$(_assets_stamp).tar.bz2

.PHONY: assets
assets: $(ASSETS_BITS)

$(ASSETS_BITS): build/assets
	@echo "# Build assets: branch $(ASSETS_BRANCH), sha $(ASSETS_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/assets && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created assets bits:"
	@ls -1 $(ASSETS_BITS)
	@echo ""

clean_assets:
	rm -rf $(BITS_DIR)/assets
	(cd build/assets && gmake clean)

#---- ADMINUI

_adminui_stamp=$(ADMINUI_BRANCH)-$(TIMESTAMP)-g$(ADMINUI_SHA)
ADMINUI_BITS=$(BITS_DIR)/adminui/adminui-pkg-$(_adminui_stamp).tar.bz2

.PHONY: adminui
adminui: $(ADMINUI_BITS)

$(ADMINUI_BITS): build/adminui
	@echo "# Build adminui: branch $(ADMINUI_BRANCH), sha $(ADMINUI_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/adminui && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created adminui bits:"
	@ls -1 $(ADMINUI_BITS)
	@echo ""

clean_adminui:
	rm -rf $(BITS_DIR)/adminui
	(cd build/adminui && gmake clean)

#---- PORTAL

_portal_stamp=$(PORTAL_BRANCH)-$(TIMESTAMP)-g$(PORTAL_SHA)
PORTAL_BITS=$(BITS_DIR)/portal/portal-pkg-$(_portal_stamp).tar.bz2

.PHONY: portal
portal: $(PORTAL_BITS)

$(PORTAL_BITS): build/portal
	@echo "# Build portal: branch $(PORTAL_BRANCH), sha $(PORTAL_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/portal && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created portal bits:"
	@ls -1 $(PORTAL_BITS)
	@echo ""

clean_portal:
	rm -rf $(BITS_DIR)/portal
	(cd build/portal && gmake clean)

#---- MAPI

_mapi_stamp=$(MAPI_BRANCH)-$(TIMESTAMP)-g$(MAPI_SHA)
MAPI_BITS=$(BITS_DIR)/mapi/mapi-pkg-$(_mapi_stamp).tar.bz2

.PHONY: mapi
mapi: $(MAPI_BITS)

$(MAPI_BITS): build/mapi
	@echo "# Build mapi: branch $(MAPI_BRANCH), sha $(MAPI_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/mapi && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created mapi bits:"
	@ls -1 $(MAPI_BITS)
	@echo ""

clean_mapi:
	rm -rf $(BITS_DIR)/mapi
	(cd build/mapi && gmake clean)

#---- RIAK

_riak_stamp=$(RIAK_BRANCH)-$(TIMESTAMP)-g$(RIAK_SHA)
RIAK_BITS=$(BITS_DIR)/riak/riak-pkg-$(_riak_stamp).tar.bz2

.PHONY: riak
riak: $(RIAK_BITS)

$(RIAK_BITS): build/riak
	@echo "# Build riak: branch $(RIAK_BRANCH), sha $(RIAK_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/riak && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created riak bits:"
	@ls -1 $(RIAK_BITS)
	@echo ""

clean_riak:
	rm -rf $(BITS_DIR)/riak
	(cd build/riak && gmake clean)

#---- REDIS

_redis_stamp=$(REDIS_BRANCH)-$(TIMESTAMP)-g$(REDIS_SHA)
REDIS_BITS=$(BITS_DIR)/redis/redis-pkg-$(_redis_stamp).tar.bz2

.PHONY: redis
redis: $(REDIS_BITS)

$(REDIS_BITS): build/redis
	@echo "# Build redis: branch $(REDIS_BRANCH), sha $(REDIS_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/redis && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created redis bits:"
	@ls -1 $(REDIS_BITS)
	@echo ""

clean_redis:
	rm -rf $(BITS_DIR)/redis
	(cd build/redis && gmake clean)

#---- RABBITMQ

_rabbitmq_stamp=$(RABBITMQ_BRANCH)-$(TIMESTAMP)-g$(RABBITMQ_SHA)
RABBITMQ_BITS=$(BITS_DIR)/rabbitmq/rabbitmq-pkg-$(_rabbitmq_stamp).tar.bz2

.PHONY: rabbitmq
rabbitmq: $(RABBITMQ_BITS)

$(RABBITMQ_BITS): build/rabbitmq
	@echo "# Build rabbitmq: branch $(RABBITMQ_BRANCH), sha $(RABBITMQ_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/rabbitmq && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created rabbitmq bits:"
	@ls -1 $(RABBITMQ_BITS)
	@echo ""

clean_rabbitmq:
	rm -rf $(BITS_DIR)/rabbitmq
	(cd build/rabbitmq && gmake clean)

#---- DHCPD

_dhcpd_stamp=$(DHCPD_BRANCH)-$(TIMESTAMP)-g$(DHCPD_SHA)
DHCPD_BITS=$(BITS_DIR)/dhcpd/dhcpd-pkg-$(_dhcpd_stamp).tar.bz2

.PHONY: dhcpd
dhcpd: $(DHCPD_BITS)

$(DHCPD_BITS): build/dhcpd
	@echo "# Build dhcpd: branch $(DHCPD_BRANCH), sha $(DHCPD_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/dhcpd && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) \
		$(MAKE) release publish)
	@echo "# Created dhcpd bits:"
	@ls -1 $(DHCPD_BITS)
	@echo ""

clean_dhcpd:
	rm -rf $(BITS_DIR)/dhcpd
	(cd build/dhcpd && gmake clean)

#---- WEBINFO

_webinfo_stamp=$(WEBINFO_BRANCH)-$(TIMESTAMP)-g$(WEBINFO_SHA)
WEBINFO_BITS=$(BITS_DIR)/webinfo/webinfo-pkg-$(_webinfo_stamp).tar.bz2

.PHONY: webinfo
webinfo: $(WEBINFO_BITS)

$(WEBINFO_BITS): build/webinfo
	@echo "# Build webinfo: branch $(WEBINFO_BRANCH), sha $(WEBINFO_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/webinfo && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) $(MAKE) release publish)
	@echo "# Created webinfo bits:"
	@ls -1 $(WEBINFO_BITS)
	@echo ""

clean_webinfo:
	rm -rf $(BITS_DIR)/webinfo
	(cd build/webinfo && gmake clean)

#---- CLOUDAPI

_cloudapi_stamp=$(CLOUDAPI_BRANCH)-$(TIMESTAMP)-g$(CLOUDAPI_SHA)
CLOUDAPI_BITS=$(BITS_DIR)/cloudapi/cloudapi-pkg-$(_cloudapi_stamp).tar.bz2

.PHONY: cloudapi
cloudapi: $(CLOUDAPI_BITS)

# cloudapi still uses platform node, ensure that same version is first
# node (and npm) on the PATH.
$(CLOUDAPI_BITS): build/cloudapi
	@echo "# Build cloudapi: branch $(CLOUDAPI_BRANCH), sha $(CLOUDAPI_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/cloudapi && PATH=/opt/node/0.6.12/bin:$(PATH) TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created cloudapi bits:"
	@ls -1 $(CLOUDAPI_BITS)
	@echo ""

# Warning: if cloudapi's submodule deps change, this 'clean_ufds' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_cloudapi:
	rm -rf $(BITS_DIR)/cloudapi
	(cd build/cloudapi && gmake clean)


#---- MANATEE

_manatee_stamp=$(MANATEE_BRANCH)-$(TIMESTAMP)-g$(MANATEE_SHA)
MANATEE_BITS=$(BITS_DIR)/manatee/manatee-pkg-$(_manatee_stamp).tar.bz2

.PHONY: manatee
manatee: $(MANATEE_BITS)

# PATH for manatee build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MANATEE_BITS): build/manatee
	@echo "# Build manatee: branch $(MANATEE_BRANCH), sha $(MANATEE_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/manatee && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created manatee bits:"
	@ls -1 $(MANATEE_BITS)
	@echo ""

# Warning: if manatee's submodule deps change, this 'clean_manatee' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_manatee:
	rm -rf $(BITS_DIR)/manatee
	(cd build/manatee && gmake clean)


#---- WORKFLOW

_wf_stamp=$(WORKFLOW_BRANCH)-$(TIMESTAMP)-g$(WORKFLOW_SHA)
WORKFLOW_BITS=$(BITS_DIR)/workflow/workflow-pkg-$(_wf_stamp).tar.bz2

.PHONY: workflow
workflow: $(WORKFLOW_BITS)

# PATH for workflow build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(WORKFLOW_BITS): build/workflow
	@echo "# Build workflow: branch $(WORKFLOW_BRANCH), sha $(WORKFLOW_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/workflow && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created workflow bits:"
	@ls -1 $(WORKFLOW_BITS)
	@echo ""

# Warning: if workflow's submodule deps change, this 'clean_workflow' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_workflow:
	rm -rf $(BITS_DIR)/workflow
	(cd build/workflow && gmake clean)


#---- ZAPI

_zapi_stamp=$(ZAPI_BRANCH)-$(TIMESTAMP)-g$(ZAPI_SHA)
ZAPI_BITS=$(BITS_DIR)/zapi/zapi-pkg-$(_zapi_stamp).tar.bz2

.PHONY: zapi
zapi: $(ZAPI_BITS)

# PATH for zapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(ZAPI_BITS): build/zapi
	@echo "# Build zapi: branch $(ZAPI_BRANCH), sha $(ZAPI_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/zapi && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created zapi bits:"
	@ls -1 $(ZAPI_BITS)
	@echo ""

# Warning: if zapi's submodule deps change, this 'clean_zapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_zapi:
	rm -rf $(BITS_DIR)/zapi
	(cd build/zapi && gmake clean)


#---- DAPI

_dapi_stamp=$(DAPI_BRANCH)-$(TIMESTAMP)-g$(DAPI_SHA)
DAPI_BITS=$(BITS_DIR)/dapi/dapi-pkg-$(_dapi_stamp).tar.bz2

.PHONY: dapi
dapi: $(DAPI_BITS)

# PATH for dapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(DAPI_BITS): build/dapi
	@echo "# Build dapi: branch $(DAPI_BRANCH), sha $(DAPI_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/dapi && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created dapi bits:"
	@ls -1 $(DAPI_BITS)
	@echo ""

# Warning: if dapi's submodule deps change, this 'clean_dapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_dapi:
	rm -rf $(BITS_DIR)/dapi
	(cd build/dapi && gmake clean)


#---- CNAPI

_cnapi_stamp=$(CNAPI_BRANCH)-$(TIMESTAMP)-g$(CNAPI_SHA)
CNAPI_BITS=$(BITS_DIR)/cnapi/cnapi-pkg-$(_cnapi_stamp).tar.bz2

.PHONY: cnapi
cnapi: $(CNAPI_BITS)

# PATH for cnapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(CNAPI_BITS): build/cnapi
	@echo "# Build cnapi: branch $(CNAPI_BRANCH), sha $(CNAPI_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/cnapi && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created cnapi bits:"
	@ls -1 $(CNAPI_BITS)
	@echo ""

# Warning: if cnapi's submodule deps change, this 'clean_cnapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_cnapi:
	rm -rf $(BITS_DIR)/cnapi
	(cd build/cnapi && gmake clean)


#---- NAPI

_napi_stamp=$(NAPI_BRANCH)-$(TIMESTAMP)-g$(NAPI_SHA)
NAPI_BITS=$(BITS_DIR)/napi/napi-pkg-$(_napi_stamp).tar.bz2

.PHONY: napi
napi: $(NAPI_BITS)

# PATH for napi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(NAPI_BITS): build/napi
	@echo "# Build napi: branch $(NAPI_BRANCH), sha $(NAPI_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/napi && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake pkg release publish)
	@echo "# Created napi bits:"
	@ls -1 $(NAPI_BITS)
	@echo ""

# Warning: if NAPI's submodule deps change, this 'clean_napi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_napi:
	rm -rf $(BITS_DIR)/napi
	(cd build/napi && gmake clean)


#---- Moray

_moray_stamp=$(MORAY_BRANCH)-$(TIMESTAMP)-g$(MORAY_SHA)
MORAY_BITS=$(BITS_DIR)/moray/moray-pkg-$(_moray_stamp).tar.bz2

.PHONY: moray
moray: $(MORAY_BITS)

# PATH for moray build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(MORAY_BITS): build/moray
	@echo "# Build moray: branch $(MORAY_BRANCH), sha $(MORAY_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/moray && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created moray bits:"
	@ls -1 $(MORAY_BITS)
	@echo ""

clean_moray:
	rm -rf $(BITS_DIR)/moray
	(cd build/moray && gmake distclean)


#---- DCAPI

_dcapi_stamp=$(DCAPI_BRANCH)-$(TIMESTAMP)-g$(DCAPI_SHA)
DCAPI_BITS=$(BITS_DIR)/dcapi/dcapi-pkg-$(_dcapi_stamp).tar.bz2

.PHONY: dcapi
dcapi: $(DCAPI_BITS)

# PATH for dcapi build: Ensure /opt/local/bin is first to put gcc 4.5 (from
# pkgsrc) before other GCCs.
$(DCAPI_BITS): build/dcapi
	@echo "# Build dcapi: branch $(DCAPI_BRANCH), sha $(DCAPI_SHA)"
	mkdir -p $(BITS_DIR)
	(cd build/dcapi && TIMESTAMP=$(TIMESTAMP) BITS_DIR=$(BITS_DIR) gmake release publish)
	@echo "# Created dcapi bits:"
	@ls -1 $(DCAPI_BITS)
	@echo ""

# Warning: if DCAPI's submodule deps change, this 'clean_dcapi' is insufficient. It would
# then need to call 'gmake dist-clean'.
clean_dcapi:
	rm -rf $(BITS_DIR)/dcapi
	(cd build/dcapi && gmake clean)


#---- agents shar

_as_stamp=$(AGENTS_INSTALLER_BRANCH)-$(TIMESTAMP)-g$(AGENTS_INSTALLER_SHA)
AGENTSSHAR_BITS=$(BITS_DIR)/agentsshar/agents-$(_as_stamp).sh \
	$(BITS_DIR)/agentsshar/agents-$(_as_stamp).md5sum
AGENTSSHAR_BITS_0=$(shell echo $(AGENTSSHAR_BITS) | awk '{print $$1}')

.PHONY: agentsshar
agentsshar: $(AGENTSSHAR_BITS_0)

$(AGENTSSHAR_BITS): build/agents-installer/Makefile
	@echo "# Build agentsshar: branch $(AGENTS_INSTALLER_BRANCH), sha $(AGENTS_INSTALLER_SHA)"
	mkdir -p $(BITS_DIR)/agentsshar
	(cd build/agents-installer && PATH=$(shell dirname $(MG_NODE)):$(PATH) TIMESTAMP=$(TIMESTAMP) ./mk-agents-shar -o $(BITS_DIR)/agentsshar/ -d $(BITS_DIR) -b $(AGENTS_INSTALLER_BRANCH))
	@echo "# Created agentsshar bits:"
	@ls -1 $(AGENTSSHAR_BITS)
	@echo ""

clean_agentsshar:
	rm -rf $(BITS_DIR)/agentsshar
	(if [[ -d build/agents-installer ]]; then cd build/agents-installer && gmake clean; fi )



#---- usb-headnode
# We are using the '-s STAGE-DIR' option to the usb-headnode build to
# avoid rebuilding it. We use the "boot" target to build the stage dir
# and have the other usb-headnode targets depend on that.
#
# TODO:
# - solution for datasets
# - pkgsrc isolation

.PHONY: usbheadnode
usbheadnode: boot coal usb upgrade

_usbheadnode_stamp=$(USB_HEADNODE_BRANCH)-$(TIMESTAMP)-g$(USB_HEADNODE_SHA)


BOOT_BIT=$(BITS_DIR)/usbheadnode/boot-$(_usbheadnode_stamp).tgz

.PHONY: boot
boot: $(BOOT_BIT)

$(BOOT_BIT): bits/usbheadnode/build.spec.local
	@echo "# Build boot: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA)"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& PATH=$(shell dirname $(MG_NODE)):$(PATH) \
		BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build PKGSRC_DIR=$(TOP)/build/pkgsrc ./bin/build-tar-image -c
	mv build/usb-headnode/$(shell basename $(BOOT_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created boot bits:"
	@ls -1 $(BOOT_BIT)
	@echo ""


COAL_BIT=$(BITS_DIR)/usbheadnode/coal-$(_usbheadnode_stamp)-4gb.tgz

bits/usbheadnode/build.spec.local:
	mkdir -p bits/usbheadnode
	sed -e "s/{{BRANCH}}/$(USB_HEADNODE_BRANCH)/" <build.spec.in >bits/usbheadnode/build.spec.local
	(cd build/usb-headnode; rm -f build.spec.local; ln -s ../../bits/usbheadnode/build.spec.local)

.PHONY: coal
coal: usb $(COAL_BIT)

$(COAL_BIT): bits/usbheadnode/build.spec.local $(USB_BIT)
	@echo "# Build coal: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA)"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& PATH=$(shell dirname $(MG_NODE)):$(PATH) \
		BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build PKGSRC_DIR=$(TOP)/build/pkgsrc ./bin/build-coal-image -c $(USB_BIT)
	mv build/usb-headnode/$(shell basename $(COAL_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created coal bits:"
	@ls -1 $(COAL_BIT)
	@echo ""

USB_BIT=$(BITS_DIR)/usbheadnode/usb-$(_usbheadnode_stamp).tgz

.PHONY: usb
usb: $(USB_BIT)

$(USB_BIT): bits/usbheadnode/build.spec.local $(BOOT_BIT)
	@echo "# Build usb: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA)"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& PATH=$(shell dirname $(MG_NODE)):$(PATH) \
		BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build PKGSRC_DIR=$(TOP)/build/pkgsrc ./bin/build-usb-image -c $(BOOT_BIT)
	mv build/usb-headnode/$(shell basename $(USB_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created usb bits:"
	@ls -1 $(USB_BIT)
	@echo ""

UPGRADE_BIT=$(BITS_DIR)/usbheadnode/upgrade-$(_usbheadnode_stamp).tgz

.PHONY: upgrade
upgrade: $(UPGRADE_BIT)

$(UPGRADE_BIT): bits/usbheadnode/build.spec.local $(BOOT_BIT)
	@echo "# Build upgrade: usb-headnode branch $(USB_HEADNODE_BRANCH), sha $(USB_HEADNODE_SHA)"
	mkdir -p $(BITS_DIR)/usbheadnode
	cd build/usb-headnode \
		&& PATH=$(shell dirname $(MG_NODE)):$(PATH) \
		BITS_URL=$(TOP)/bits TIMESTAMP=$(TIMESTAMP) \
		ZONE_DIR=$(TOP)/build PKGSRC_DIR=$(TOP)/build/pkgsrc ./bin/build-upgrade-image $(BOOT_BIT)
	mv build/usb-headnode/$(shell basename $(UPGRADE_BIT)) $(BITS_DIR)/usbheadnode
	@echo "# Created upgrade bits:"
	@ls -1 $(UPGRADE_BIT)
	@echo ""


RELEASEJSON_BIT=$(BITS_DIR)/usbheadnode/release.json

.PHONY: releasejson
releasejson:
	mkdir -p $(BITS_DIR)/usbheadnode
	echo "{ \
	\"date\": \"$(TIMESTAMP)\", \
	\"branch\": \"$(BRANCH)\", \
	\"try-branch\": \"$(TRY-BRANCH)\", \
	\"coal\": \"$(shell basename $(COAL_BIT))\", \
	\"boot\": \"$(shell basename $(BOOT_BIT))\", \
	\"usb\": \"$(shell basename $(USB_BIT))\", \
	\"upgrade\": \"$(shell basename $(UPGRADE_BIT))\" \
}" | $(JSON) >$(RELEASEJSON_BIT)


clean_usb-headnode:
	rm -rf $(BOOT_BIT) $(UPGRADE_BIT) $(USB_BIT) $(COAL_BIT)



#---- platform

PLATFORM_BITS=$(BITS_DIR)/platform/platform-$(ILLUMOS_LIVE_BRANCH)-$(TIMESTAMP).tgz \
	$(BITS_DIR)/platform/vmtests-$(ILLUMOS_LIVE_BRANCH)-$(TIMESTAMP).tgz
PLATFORM_BITS_0=$(shell echo $(PLATFORM_BITS) | awk '{print $$1}')

.PHONY: platform
platform: $(PLATFORM_BITS_0)

build/illumos-live/configure.mg:
	sed -e "s/BRANCH/$(ILLUMOS_LIVE_BRANCH)/" -e "s:GITCLONESOURCE:$(shell pwd)/build/:" <illumos-configure.tmpl >build/illumos-live/configure.mg

build/illumos-live/configure-branches:
	sed -e "s/BRANCH/$(ILLUMOS_LIVE_BRANCH)/" <illumos-configure-branches.tmpl >build/illumos-live/configure-branches

# PATH: Ensure using GCC from SFW as require for platform build.
$(PLATFORM_BITS): build/illumos-live/configure.mg build/illumos-live/configure-branches
	@echo "# Build platform: branch $(ILLUMOS_LIVE_BRANCH), sha $(ILLUMOS_LIVE_SHA)"
	(cd build/illumos-live \
		&& PATH=/usr/sfw/bin:$(PATH) \
			EXTRA_TARBALL=$(shell ls -1 $(BITS_DIR)/illumosextra/illumos-extra-* | tail -1) \
			./configure \
		&& PATH=/usr/sfw/bin:$(PATH) \
			EXTRA_TARBALL=$(shell ls -1 $(BITS_DIR)/illumosextra/illumos-extra-* | tail -1) \
			BUILDSTAMP=$(TIMESTAMP) \
			gmake world \
		&& PATH=/usr/sfw/bin:$(PATH) \
			BUILDSTAMP=$(TIMESTAMP) \
			EXTRA_TARBALL=$(shell ls -1 $(BITS_DIR)/illumosextra/illumos-extra-* | tail -1) \
			gmake live)
	(mkdir -p $(BITS_DIR)/platform)
	(cp build/illumos-live/output/platform-$(TIMESTAMP).tgz $(BITS_DIR)/platform/platform-$(ILLUMOS_LIVE_BRANCH)-$(TIMESTAMP).tgz)
	cp build/illumos-live/output/vmtests-$(TIMESTAMP).tgz $(BITS_DIR)/platform/vmtests-$(ILLUMOS_LIVE_BRANCH)-$(TIMESTAMP).tgz
	@echo "# Created platform bits:"
	@ls -1 $(PLATFORM_BITS)
	@echo ""

clean_platform:
	rm -rf $(BITS_DIR)/platform
	(cd build/illumos-live && gmake clean)

#---- extras

ILLUMOSEXTRA_TARBALL=illumos-extra-$(ILLUMOS_EXTRA_BRANCH)-$(TIMESTAMP)-g$(ILLUMOS_EXTRA_SHA).tgz
ILLUMOSEXTRA_BIT=$(BITS_DIR)/illumosextra/$(ILLUMOSEXTRA_TARBALL)

.PHONY: illumosextra

illumosextra: $(ILLUMOSEXTRA_BIT)

# PATH: Ensure using GCC from SFW as require for platform build.
$(ILLUMOSEXTRA_BIT):
	@echo "# Build illumosextra: branch $(ILLUMOS_EXTRA_BRANCH), sha $(ILLUMOS_EXTRA_SHA)"
	(cd build/illumos-extra && PATH=/usr/sfw/bin:$(PATH) TIMESTAMP=$(TIMESTAMP) gmake install && PATH=/usr/sfw/bin:$(PATH) TIMESTAMP=$(TIMESTAMP) gmake tarball )
	(mkdir -p $(BITS_DIR)/illumosextra;  cp build/illumos-extra/$(ILLUMOSEXTRA_TARBALL) $(BITS_DIR)/illumosextra)
	@echo "# Created illumosextra bits:"
	@ls -1 $(ILLUMOSEXTRA_BIT)
	@echo ""

clean_illumosextra:
	rm -rf $(BITS_DIR)/illumosextra
	(cd build/illumos-extra && gmake clean)



#---- docs target (based on eng.git/tools/mk code for this)

deps/%/.git:
	git submodule update --init deps/$*

RESTDOWN_EXEC	?= deps/restdown/bin/restdown
RESTDOWN	?= python2.6 $(RESTDOWN_EXEC)
RESTDOWN_FLAGS	?=
DOC_FILES	= design.restdown index.restdown
DOC_BUILD	= build/docs/public

$(DOC_BUILD):
	mkdir -p $@

$(DOC_BUILD)/%.json $(DOC_BUILD)/%.html: docs/%.restdown | $(DOC_BUILD) $(RESTDOWN_EXEC)
	$(RESTDOWN) $(RESTDOWN_FLAGS) -m $(DOC_BUILD) $<
	mv $(<:%.restdown=%.json) $(DOC_BUILD)
	mv $(<:%.restdown=%.html) $(DOC_BUILD)

.PHONY: docs
docs:							\
    $(DOC_FILES:%.restdown=$(DOC_BUILD)/%.html)		\
    $(DOC_FILES:%.restdown=$(DOC_BUILD)/%.json)

$(RESTDOWN_EXEC): | deps/restdown/.git

clean_docs:
	rm -rf build/docs



#---- misc targets

.PHONY: clean
clean: clean_docs

.PHONY: clean_null
clean_null:

.PHONY: distclean
distclean:
	pfexec rm -rf bits build

.PHONY: cacheclean
cacheclean: distclean
	pfexec rm -rf cache



# Upload bits we want to keep for a Jenkins build.
upload_jenkins:
	@[[ -z "$(JOB_NAME)" ]] \
		&& echo "error: JOB_NAME isn't set (is this being run under Jenkins?)" \
		&& exit 1 || true
	./tools/upload-bits "$(BRANCH)" "$(TRY_BRANCH)" "$(TIMESTAMP)" $(UPLOAD_LOCATION)/$(JOB_NAME)

include bits/config.targ.mk
