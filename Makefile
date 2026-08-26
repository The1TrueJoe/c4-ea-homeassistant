# c4-ea-homeassistant — Home Assistant on top of openHC's EA1/EA3 bare kernel
# build.
#
# openHC (vendored as the `openHC/` submodule) stays generic: kernel, netboot,
# base rootfs, nothing HA-specific. This Makefile builds one extra defconfig
# layer on top of it (board/<BOARD>) that adds what HA needs — see
# build/build.sh for how the layers combine.

BOARD ?= ea3-ha
# ea3-ha: what's actually on the bench right now.
# ea1-ha: openHC's proven-on-hardware board; same split, different base.
BOARDS := ea1-ha ea3-ha

ifeq ($(filter $(BOARD),$(BOARDS)),)
  $(error BOARD must be one of: $(BOARDS)  (got '$(BOARD)'))
endif

.PHONY: help image

help:
	@echo "c4-ea-homeassistant — EA1/EA3 + Home Assistant build"
	@echo ""
	@echo "  make image [BOARD=...]   build the image (Docker Buildroot, layers on openHC)"
	@echo ""
	@echo "  current BOARD=$(BOARD)   (supported: $(BOARDS))"
	@echo ""
	@echo "  Needs the openHC submodule checked out:"
	@echo "    git submodule update --init openHC"

image:
	@test -f openHC/board/ea-common/ea-common_defconfig || { \
		echo "openHC submodule not checked out — run:"; \
		echo "  git submodule update --init openHC"; exit 1; }
	DOCKER_BUILDKIT=1 docker build -f build/Dockerfile --target artifacts \
		--build-arg BOARD=$(BOARD) $(if $(JOBS),--build-arg BR2_JLEVEL=$(JOBS)) \
		--output type=local,dest=output/images .
