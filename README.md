# vpnc-dnsmasq-socks5
[![license](https://img.shields.io/github/license/b0ch3nski/vpnc-dnsmasq-socks5)](LICENSE)
[![release](https://img.shields.io/github/v/release/b0ch3nski/vpnc-dnsmasq-socks5)](https://github.com/b0ch3nski/vpnc-dnsmasq-socks5/releases)
[![issues](https://img.shields.io/github/issues/b0ch3nski/vpnc-dnsmasq-socks5)](https://github.com/b0ch3nski/vpnc-dnsmasq-socks5/issues)

All-in-one Docker image with [vpnc][vpnc], [dnsmasq][dnsmasq], [microsocks][microsocks] and [redsocks][redsocks].

This is a wrapper around several tools to fight against oppressive VPN solutions. Each container gets it's own isolated
network namespace which keeps `vpnc` away from messing up with the host routing. Since VPN provided DNS server is often
slow, `dnsmasq` is used to blend it with server of your choice (or host default). SOCKS5 server `microsocks` is exposed
to provide external access to the container network. For special cases where you need to use proxy after VPN connection,
`redsocks` is used to redirect all traffic through it.

**TL;DR:** The aim of this project is convenience, not privacy - if you're looking for the other one, this solution is
not for you.

[vpnc]: https://github.com/streambinder/vpnc
[dnsmasq]: https://thekelleys.org.uk/dnsmasq/doc.html
[microsocks]: https://github.com/rofl0r/microsocks
[redsocks]: https://github.com/darkk/redsocks

## usage

```sh
docker run \
    --detach \
    --name="vpnc" \
    --restart unless-stopped \
    --cap-add NET_ADMIN \
    --security-opt="no-new-privileges:true" \
    --device /dev/net/tun:/dev/net/tun \
    --publish 127.0.0.1:1080:1080/tcp \
    --publish 127.0.0.1:1180:1180/tcp \
    --publish 127.0.0.1:53:53/udp \
    --volume "${HOME}/.config/hosts:/tmp/hosts:ro" \
    --env DEBUG="on" \
    --env MAIN_DNS="1.1.1.1" \
    --env IPSEC_GATEWAY="my.vpnc-gateway.com" \
    --env IPSEC_ID="some-id-here" \
    --env IPSEC_SECRET="very-long-secret" \
    --env XAUTH_USER="john@doe.com" \
    --env XAUTH_PASS="ImH4Ck3r!" \
    --env TOTP_KEY="xxxxxxxxxxxxxxxx" \
    --env PROXY_HOST="192.168.1.1" \
    --env PROXY_PORT="1080" \
    b0ch3nski/vpnc-dnsmasq-socks5:latest
```

I recommend going through [init.sh](init.sh) for a better understanding how this works.

### TOTP

When presented with QR code, decode it. The result will look similar to example below - use content of `secret` param:
```
otpauth://totp/<...>?secret=xxxxxxxxxxxxxxxx
```

## wireguard

Initially I've made this as a workaround for using `vpnc` in an isolated environment - which did it's job fine for
months. Lately I've started toying around with [Cloudflare Zero Trust WARP][cf-warp] (which essentially is based on
`wireguard`) and decided that I might reuse some of the code base from this project. It turned out that changes are so
small I could make it work in a single repo without breaking anything.

Wireguard support has been added in **v0.4** and can be controlled using following environment variables:
```sh
--env WG_ENDPOINT="engage.cloudflareclient.com:2408" \
--env WG_PUBLIC_KEY="my-public-key" \
--env WG_PRIVATE_KEY="my-private-key" \
--env WG_ADDRESS="100.96.0.2" \
--env WG_MTU="1280" \
--env WG_ALLOWED_IPS="100.64.0.0/10, 1.1.1.1/32, 1.0.0.1/32" \
--env MAIN_DNS="1.1.1.1 1.0.0.1" \
...
```

If you are also interested in using [Cloudflare WARP][cf-warp], config for Wireguard can be easily obtained using
[warp.sh][warp.sh] script.

[cf-warp]: https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp
[warp.sh]: https://github.com/rany2/warp.sh

## disclaimer

This project was made for fun and learning purposes and shall not be used in real workloads. Use it with extra care and
only at your own risk.
