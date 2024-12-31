# syntax=docker/dockerfile:1.12-labs
ARG DEBIAN_VERSION
FROM debian:${DEBIAN_VERSION}-slim
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN apt-get update; \
    apt-get install -y --no-install-recommends --no-install-suggests \
        ca-certificates \
        wireguard-tools \
        netcat-openbsd \
        microsocks \
        iproute2 \
        iptables \
        oathtool \
        redsocks \
        dnsmasq \
        procps \
        curl \
        gosu \
        vpnc; \
    useradd --gid nogroup --no-create-home --shell="/usr/sbin/nologin" microsocks; \
    rm -rfv \
        /var/lib/apt/lists/* \
        /var/log/* \
        /var/tmp/* \
        /tmp/*

COPY init.sh /usr/local/bin/

EXPOSE 53/udp 1080/tcp 1180/tcp

CMD ["init.sh"]
