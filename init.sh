#!/usr/bin/env bash
set -Eeo pipefail

RESOLV_CONF="/etc/resolv.conf"
VPNC_CONF="/etc/vpnc/vpn.conf"
DNS_CONF="/etc/dnsmasq.d/dns.conf"

wait_for_port() { while ! nc -z 127.0.0.1 ${1}; do sleep 0.5; done; }
get_resolv_nameserver() { awk '/^nameserver/ { print $2; exit }' "${RESOLV_CONF}"; }
curl_wrapper() { curl --insecure --location --silent --show-error --fail-with-body --max-time 10 --socks5-hostname "127.0.0.1:${MICROSOCKS_PORT}" --write-out "\n" "${1}"; }
print_current_ip() { echo -e "==> Current public IP address:\n$(curl_wrapper "http://api.ipify.org")"; }


: "${MICROSOCKS_PORT:=1080}"
echo "==> Starting MicroSocks"
gosu microsocks microsocks -i 0.0.0.0 -p ${MICROSOCKS_PORT} &
wait_for_port ${MICROSOCKS_PORT}
echo "==> MicroSocks started"

DNS_SERVERS=( $(echo ${MAIN_DNS:-$(get_resolv_nameserver)} ${EXTRA_DNS}) )
echo -e "==> Got DNS servers:\n${DNS_SERVERS[@]}"

# start VPNC when all required variables are set
if [ "${IPSEC_GATEWAY}" ] && [ "${IPSEC_ID}" ] && [ "${IPSEC_SECRET}" ] && [ "${XAUTH_USER}" ] && [ "${XAUTH_PASS}" ]; then
    print_current_ip

    DEFAULT_ROUTE="$(ip -4 route | grep '^default' | head -1)"
    DEFAULT_GATEWAY="$(awk '{ print $3 }' <<< ${DEFAULT_ROUTE})"
    DEFAULT_INTERFACE="$(awk '{ print $5 }' <<< ${DEFAULT_ROUTE})"

    for dns in "${DNS_SERVERS[@]}"; do
        # always route Non-VPN DNS servers through default gateway and interface
        ip -4 route add "${dns}/32" via "${DEFAULT_GATEWAY}" dev "${DEFAULT_INTERFACE}"
        echo "==> Routing DNS server '${dns}' via '${DEFAULT_GATEWAY}' through '${DEFAULT_INTERFACE}'"

        # drop negative responses (NXDOMAIN) on Non-VPN DNS servers
        iptables -A INPUT -s "${dns}/32" -p tcp -m tcp --sport 53 -m u32 --u32 "54 & 0x000F = 0x3" -j DROP
        iptables -A INPUT -s "${dns}/32" -p udp -m udp --sport 53 -m u32 --u32 "28 & 0x000F = 0x3" -j DROP
    done

    : "${VPN_INTERFACE:=tun123}"
    cat << EOF > "${VPNC_CONF}"
IPSec gateway ${IPSEC_GATEWAY}
IPSec ID ${IPSEC_ID}
IPSec obfuscated secret ${IPSEC_SECRET}
IKE Authmode psk
Xauth username ${XAUTH_USER}
Xauth password ${XAUTH_PASS}
DPD idle timeout (our side) 0
Enable weak encryption
Enable weak authentication
Interface mode tun
Interface name ${VPN_INTERFACE}
Script /usr/share/vpnc-scripts/vpnc-script
EOF
    [ "${DEBUG}" = "on" ] && echo "Debug 1" >> "${VPNC_CONF}"

    : "${TOTP_PASS:=$(oathtool --totp --base32 ${TOTP_KEY})}"
    echo -e "==> Got TOTP password:\n${TOTP_PASS}"

    echo "==> Starting VPNC to '${IPSEC_GATEWAY}' as '${XAUTH_USER}'..."
    echo "${TOTP_PASS}" | vpnc vpn
    echo

    echo "==> Waiting for VPNC initialization"
    while ! grep -q VPNC "${RESOLV_CONF}"; do sleep 0.5; done
    echo "==> VPNC started"

    VPNC_DNS="$(get_resolv_nameserver)"
    echo -e "==> DNS server from VPNC:\n${VPNC_DNS}"
    DNS_SERVERS+=( $(echo ${VPNC_DNS}) )

    # handle traffic routed from outside of the container so it can be used as a gateway
    iptables -t nat -A POSTROUTING -o "${VPN_INTERFACE}" -j MASQUERADE
fi

# when $PROXY_HOST and $PROXY_PORT are set, use REDSOCKS to forward all traffic made by microsocks user through this proxy
if [ "${PROXY_HOST}" ] && [ "${PROXY_PORT}" ]; then
    : "${REDSOCKS_PORT:=12345}"
    cat << EOF > /etc/redsocks.conf
base {
  log_info = ${DEBUG:-off};
  log_debug = ${DEBUG:-off};
  daemon = off;
  user = redsocks;
  group = redsocks;
  redirector = iptables;
}
redsocks {
  local_ip = 127.0.0.1;
  local_port = ${REDSOCKS_PORT};
  type = socks5;
  ip = ${PROXY_HOST};
  port = ${PROXY_PORT};
}
EOF

    echo "==> Starting REDSOCKS"
    redsocks &
    wait_for_port ${REDSOCKS_PORT}
    echo "==> REDSOCKS started"

    # create NAT chain for REDSOCKS and ignore common reserved addresses
    iptables -t nat -N REDSOCKS
    iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN

    # redirect all TCP connections to REDSOCKS port
    iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports "${REDSOCKS_PORT}"

    # use REDSOCKS chain for all outgoing TCP connections made by microsocks user
    iptables -t nat -A OUTPUT -p tcp -m owner --uid-owner microsocks -j REDSOCKS

    # start another instance of MicroSocks to handle connections that should not go through the proxy
    : "${MICROSOCKS_NOPROXY_PORT:=1180}"
    echo "==> Starting MicroSocks (proxy bypass)"
    gosu nobody microsocks -i 0.0.0.0 -p ${MICROSOCKS_NOPROXY_PORT} &
    wait_for_port ${MICROSOCKS_NOPROXY_PORT}
    echo "==> MicroSocks (proxy bypass) started"
fi

: "${DNS_CACHE_SIZE:=10000}"
: "${DNS_CACHE_TTL:=900}"
: "${ADDN_HOSTS_FILE:=/tmp/hosts}"
cat << EOF > "${DNS_CONF}"
port=53
cache-size=${DNS_CACHE_SIZE}
no-negcache
min-cache-ttl=${DNS_CACHE_TTL}
max-cache-ttl=${DNS_CACHE_TTL}
no-hosts
no-resolv
all-servers
log-async=100
EOF
[ -f "${ADDN_HOSTS_FILE}" ] && echo "addn-hosts=${ADDN_HOSTS_FILE}" >> "${DNS_CONF}"
[ "${DEBUG}" = "on" ] && echo "log-queries=extra" >> "${DNS_CONF}"
for dns in "${DNS_SERVERS[@]}"; do
    echo "server=${dns}" >> "${DNS_CONF}"
done

echo -e "==> Starting DNSMasq with configuration:\n$(cat ${DNS_CONF})"
dnsmasq --conf-file="${DNS_CONF}" --keep-in-foreground --log-facility=- &
dnsmasq_pid="${!}"
wait_for_port 53
echo "==> DNSMasq started"

# catch HUP signal and propagate to dnsmasq - clear cache & reload hosts
trap 'kill -SIGHUP ${dnsmasq_pid} 2>/dev/null' HUP

# make all DNS queries through our own nameserver
echo "nameserver 127.0.0.1" > "${RESOLV_CONF}"

print_current_ip
echo -e "==> Current routing table:\n$(ip -4 route)"
echo -e "==> Current iptables rules:\n$(iptables --list-rules)"
echo -e "==> Current iptables NAT rules:\n$(iptables --table=nat --list-rules)"

trap 'echo "==> Exit signal received - goodbye!"; exit 0' INT TERM

while true; do
    curl_wrapper "${HEALTHCHECK_URL:-http://api.ipify.org}"
    sleep ${HEALTHCHECK_INTERVAL:-60} &
    wait $!
done
