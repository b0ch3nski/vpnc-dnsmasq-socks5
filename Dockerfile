# syntax=docker/dockerfile:1.9.0
FROM debian:bookworm-slim
SHELL ["/bin/bash", "-Eeuo", "pipefail", "-c"]

RUN apt-get update; \
    apt-get install -y --no-install-recommends --no-install-suggests \
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

EXPOSE 53/udp 1080/tcp

CMD ["init.sh"]
