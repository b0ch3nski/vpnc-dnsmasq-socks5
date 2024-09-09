IMAGE_NAME := b0ch3nski/vpnc-dnsmasq-socks5
IMAGE_VERSION ?= $(or $(shell git describe --tags --always),latest)
IMAGE_PLATFORMS ?= linux/amd64,linux/386,linux/arm64,linux/arm/v7

BUILD_TIME ?= $(shell date -u '+%Y-%m-%d %H:%M:%S')
LAST_COMMIT_HASH ?= $(shell git log -1 --format=%H)
LAST_COMMIT_TIME ?= $(shell git log -1 --format=%cd --date=format:'%Y-%m-%d %H:%M:%S')

DEBIAN_VERSION ?= bookworm

build:
	docker buildx build \
	--pull \
	--push \
	--platform="$(IMAGE_PLATFORMS)" \
	--build-arg DEBIAN_VERSION="$(DEBIAN_VERSION)" \
	--label="build.time=$(BUILD_TIME)" \
	--label="commit.hash=$(LAST_COMMIT_HASH)" \
	--label="commit.time=$(LAST_COMMIT_TIME)" \
	--tag="$(IMAGE_NAME):$(IMAGE_VERSION)" \
	--tag="$(IMAGE_NAME):latest" \
	.
