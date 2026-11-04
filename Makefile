# c4-ea-homeassistant — openHC EA images with Home Assistant on top.
#
# Boards come from openHC (openHC/board/ea/<board>); this repo adds one layer,
# board/ha_defconfig, to whichever is built. See build/build.sh.

BOARD ?= ea3-v2
BOARDS := $(shell build/boards.sh 2>/dev/null)

.PHONY: help boards daemons image defconfig

help:
	@echo "c4-ea-homeassistant — openHC EA image + Home Assistant layer"
	@echo ""
	@echo "  make daemons   [BOARD=...]   stage openHC's daemons into its overlay (rustup + node)"
	@echo "  make image     [BOARD=...]   build the image (Docker Buildroot)"
	@echo "  make defconfig [BOARD=...]   print the composed defconfig, build nothing"
	@echo ""
	@echo "  current BOARD=$(BOARD)   (openHC EA boards: $(BOARDS))"
	@echo ""
	@echo "  Needs the openHC submodule: git submodule update --init --recursive"

boards:
	@build/boards.sh

daemons:
	bash openHC/packages/build.sh $(BOARD)

image:
	@test -f openHC/build/build.sh || { \
		echo "openHC submodule not checked out — run:"; \
		echo "  git submodule update --init --recursive"; exit 1; }
	DOCKER_BUILDKIT=1 docker build -f build/Dockerfile --target artifacts \
		--build-arg BOARD=$(BOARD) $(if $(JOBS),--build-arg BR2_JLEVEL=$(JOBS)) \
		--output type=local,dest=output/images .

defconfig:
	@OHC_DEFCONFIG_ONLY=1 BOARD=$(BOARD) build/build.sh
