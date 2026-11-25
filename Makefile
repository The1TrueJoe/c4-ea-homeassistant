# c4-ea-homeassistant — openHC's EA images with Home Assistant, on Debian.
#
# The image is openHC's own bundle for the board (kernel, bootstrap, boot-init,
# daemons, modules, firmware, config) with a Debian root in place of
# Buildroot's. See debian/build.sh.

BOARD ?= ea3-v1
BOARDS := $(shell build/boards.sh 2>/dev/null)
# An openHC bundle (.zip or folder) for $(BOARD). Unset: download the one
# openHC's CI built for the submodule's commit (needs gh).
OPENHC_BUNDLE ?=
OUT ?= output/openhc-ha-$(BOARD).zip

.PHONY: help boards bundle image

help:
	@echo "c4-ea-homeassistant — openHC EA image with Home Assistant (Debian)"
	@echo ""
	@echo "  make image  [BOARD=...] [OPENHC_BUNDLE=path]   build $(OUT)"
	@echo "  make bundle [BOARD=...]                        fetch openHC's bundle for the submodule's commit"
	@echo ""
	@echo "  current BOARD=$(BOARD)   (openHC EA boards: $(BOARDS))"

boards:
	@build/boards.sh

bundle:
	build/openhc-bundle.sh $(BOARD) output/openhc-$(BOARD).zip

image: $(if $(OPENHC_BUNDLE),,bundle)
	docker run --rm --privileged --platform linux/amd64 -v "$(CURDIR)":/repo -w /repo debian:trixie \
		sh -c 'apt-get update -qq && apt-get install -y -qq mmdebstrap e2fsprogs unzip zip curl ca-certificates >/dev/null && ln -sf bash /bin/sh && \
		       debian/build.sh "$(or $(OPENHC_BUNDLE),output/openhc-$(BOARD).zip)" "$(OUT)"'
