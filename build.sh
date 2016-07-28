#!/usr/bin/env sh
set -eux

HAPROXY_VERSION=1.6.7
HAPROXY_SHA256=583e0c0c3388c0597dea241601f3fedfe1d7ff8c735d471831be67315f58183a

BASE=$PWD
SRC=$PWD/src
OUT=$PWD/haproxy-build
ROOTFS=$PWD/rootfs

mkdir -p $BASE/haproxy
cd $BASE
curl -OL http://www.haproxy.org/download/1.6/src/haproxy-$HAPROXY_VERSION.tar.gz
echo "$HAPROXY_SHA256  haproxy-$HAPROXY_VERSION.tar.gz" | sha256sum -c
tar -C $BASE/haproxy --strip-components 1 -xf haproxy-$HAPROXY_VERSION.tar.gz

cd $BASE/haproxy
make TARGET=linux2628 \
       USE_TFO=1 \
       CPU=native CPU_CFLAGS.native=-O3 \
       USE_PCRE_JIT=1 \
       ADDLIB="-static -L$BASE/libslz-build/lib" \
       USE_SLZ=1 ADDINC=-I$BASE/libslz-build/include \
       USE_LUA=yes LUA_LIB_NAME=lua LUA_LIB=$BASE/lua-build/lib LUA_INC=$BASE/lua-build/include \
       USE_OPENSSL=1 SSL_LIB=$BASE/libressl-build/lib SSL_INC=$BASE/libressl-build/include

mkdir -p $ROOTFS/bin $ROOTFS/var/run/haproxy

cp -r $SRC/etc $ROOTFS

cp haproxy haproxy-systemd-wrapper $ROOTFS/bin

mkdir -p $OUT

cd $ROOTFS
tar -cf $OUT/rootfs.tar .

cat <<EOF > $OUT/Dockerfile
FROM scratch

ADD rootfs.tar /

ENTRYPOINT [ "/bin/haproxy-systemd-wrapper", "-p", "/var/run/haproxy.pid" ]
CMD        [ "-f", "/etc/haproxy.cfg" ]

EOF
