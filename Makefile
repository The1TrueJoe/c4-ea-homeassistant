# c4-ea-homeassistant — Home Assistant on top of openHC's EA1 bare kernel build.
#
# openHC (vendored as the `openHC/` submodule) stays generic: kernel, netboot,
# base rootfs, nothing HA-specific. This Makefile builds one extra defconfig
# layer on top of it (board/ea1-ha) that adds what HA needs — see build/build.sh
# for how the layers combine.

IMAGE := output/images/

.PHONY: help image

help:
	@echo "c4-ea-homeassistant — EA1 + Home Assistant build"
	@echo ""
	@echo "  make image   build the ea1-ha image (Docker Buildroot, layers on openHC)"
	@echo ""
	@echo "  Needs the openHC submodule checked out:"
	@echo "    git submodule update --init openHC"

image:
	@test -f openHC/board/ea-common/ea-common_defconfig || { \
		echo "openHC submodule not checked out — run:"; \
		echo "  git submodule update --init openHC"; exit 1; }
	DOCKER_BUILDKIT=1 docker build -f build/Dockerfile --target artifacts \
		$(if $(JOBS),--build-arg BR2_JLEVEL=$(JOBS)) \
		--output type=local,dest=output/images .
