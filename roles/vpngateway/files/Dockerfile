FROM alpine:3.15

COPY entrypoint.sh /entrypoint.sh

RUN apk add --no-cache \
		wireguard-tools=1.0.20210914-r0 \
		wireguard-tools-wg-quick=1.0.20210914-r0 \
	&& sed -i '/net.ipv4.conf.all.src_valid_mark=1/s/^\([ \t]*\)/\1# /' \
		/usr/bin/wg-quick \
	&& chmod 555 /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
