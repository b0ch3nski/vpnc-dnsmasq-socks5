IMAGE_NAME := b0ch3nski/vpnc-dnsmasq-socks5
IMAGE_VERSION ?= $(or $(shell git describe --tags --always),latest)
IMAGE_PLATFORMS ?= linux/amd64,linux/386,linux/arm64,linux/arm/v7

DEBIAN_VERSION ?= bookworm

build:
	docker buildx build \
	--pull \
	--push \
	--platform="$(IMAGE_PLATFORMS)" \
	--build-arg DEBIAN_VERSION="$(DEBIAN_VERSION)" \
	--label="org.opencontainers.image.title=$(IMAGE_NAME)" \
	--label="org.opencontainers.image.version=$(IMAGE_VERSION)" \
	--label="org.opencontainers.image.url=https://github.com/$(IMAGE_NAME)" \
	--label="org.opencontainers.image.revision=$(shell git log -1 --format=%H)" \
	--label="org.opencontainers.image.created=$(shell date --iso-8601=seconds)" \
	--tag="$(IMAGE_NAME):$(IMAGE_VERSION)" \
	--tag="$(IMAGE_NAME):latest" \
	.
