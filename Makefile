# ---- Configuration ----------------------------------------------------
PACKER_VERSION  ?= 1.7.2
PWN_HOSTNAME    ?= pwnagotchi
PWN_VERSION     ?= master

# Detect architecture for the packer download (amd64/arm64 etc.)
ARCH            := $(shell uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
OS              := $(shell uname -s | tr '[:upper:]' '[:lower:]')

PACKER_URL      := https://releases.hashicorp.com/packer/$(PACKER_VERSION)/packer_$(PACKER_VERSION)_$(OS)_$(ARCH).zip
PACKER_BIN      := /usr/bin/packer
ARM_BUILDER_DIR := /tmp/packer-builder-arm-image
ARM_BUILDER_BIN := $(ARM_BUILDER_DIR)/packer-builder-arm-image

IMAGE_NAME      := pwnagotchi-raspbian-lite-$(PWN_VERSION)
BUILD_DIR       := builder
OUTPUT_DIR      := $(BUILD_DIR)/output-pwnagotchi

.PHONY: all langs install image clean help

all: clean install image

help:
	@echo "Targets:"
	@echo "  make install   - install packer + arm-image builder plugin"
	@echo "  make image     - build the pwnagotchi image"
	@echo "  make langs     - compile locale files"
	@echo "  make clean     - remove build artifacts"
	@echo "  make all       - clean, install, image"
	@echo ""
	@echo "Override vars: PACKER_VERSION=$(PACKER_VERSION) PWN_HOSTNAME=$(PWN_HOSTNAME) PWN_VERSION=$(PWN_VERSION)"

# ---- Locales ------------------------------------------------------------
langs:
	@set -e; \
	for lang in pwnagotchi/locale/*/; do \
		name=$$(basename "$$lang"); \
		echo "compiling language: $$name ..."; \
		./scripts/language.sh compile "$$name"; \
	done

# ---- Toolchain install ---------------------------------------------------
install: $(PACKER_BIN) $(ARM_BUILDER_BIN)

$(PACKER_BIN):
	@echo "==> Installing packer $(PACKER_VERSION) ($(OS)_$(ARCH))"
	curl -fsSL "$(PACKER_URL)" -o /tmp/packer.zip
	unzip -o /tmp/packer.zip -d /tmp
	sudo mv /tmp/packer $(PACKER_BIN)
	sudo chmod +x $(PACKER_BIN)
	rm -f /tmp/packer.zip

$(ARM_BUILDER_BIN):
	@echo "==> Building packer-builder-arm-image plugin"
	rm -rf $(ARM_BUILDER_DIR)
	git clone --depth 1 https://github.com/solo-io/packer-builder-arm-image $(ARM_BUILDER_DIR)
	cd $(ARM_BUILDER_DIR) && go mod download && go build -o packer-builder-arm-image
	sudo cp $(ARM_BUILDER_BIN) /usr/bin/

# ---- Image build ----------------------------------------------------------
image:
	@test -x $(PACKER_BIN) || { echo "packer not installed, run 'make install' first"; exit 1; }
	cd $(BUILD_DIR) && sudo $(PACKER_BIN) build \
		-var "pwn_hostname=$(PWN_HOSTNAME)" \
		-var "pwn_version=$(PWN_VERSION)" \
		pwnagotchi.json
	sudo mv $(OUTPUT_DIR)/image $(IMAGE_NAME).img
	sudo sha256sum $(IMAGE_NAME).img > $(IMAGE_NAME).sha256
	sudo chown $$(id -u):$$(id -g) $(IMAGE_NAME).img $(IMAGE_NAME).sha256
	zip $(IMAGE_NAME).zip $(IMAGE_NAME).sha256 $(IMAGE_NAME).img

# ---- Cleanup ----------------------------------------------------------
clean:
	rm -rf $(ARM_BUILDER_DIR)
	rm -f $(IMAGE_NAME)*.zip $(IMAGE_NAME)*.img $(IMAGE_NAME)*.sha256
	rm -rf $(OUTPUT_DIR) $(BUILD_DIR)/packer_cache
