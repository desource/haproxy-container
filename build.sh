#!/bin/sh
#
# Download and build haproxy container
set -euo pipefail

version=1.6.7
sha256=583e0c0c3388c0597dea241601f3fedfe1d7ff8c735d471831be67315f58183a

src=$PWD/haproxy
out=$PWD/out
rootfs=$PWD/rootfs

container=$PWD/container

slz=$PWD/libslz
lua=$PWD/liblua
libressl=$PWD/libressl

download() {
  mkdir -p ${src}
  curl -OL http://www.haproxy.org/download/1.6/src/haproxy-${version}.tar.gz
  echo "${sha256}  haproxy-${version}.tar.gz" | sha256sum -c
  tar -C ${src} --strip-components 1 -xf haproxy-${version}.tar.gz
}

build() {
  cd ${src}
  make TARGET=linux2628 \
         USE_TFO=1 \
         CPU=native CPU_CFLAGS.native=-O3 \
         USE_PCRE_JIT=1 \
         ADDLIB="-static -L${slz}/lib" USE_SLZ=1 ADDINC=-I${slz}/include \
         USE_LUA=yes LUA_LIB_NAME=lua LUA_LIB=${lua}/lib LUA_INC=${lua}/include \
         USE_OPENSSL=1 SSL_LIB=${libressl}/lib SSL_INC=${libressl}/include
  
  mkdir -p ${rootfs}/bin ${rootfs}/var/run/haproxy
  
  cp haproxy haproxy-systemd-wrapper ${rootfs}/bin
  
  cp -r ${container}/etc ${rootfs}
  
  cat <<EOF > ${rootfs}/etc/passwd
root:x:0:0:root:/:/dev/null
nobody:x:65534:65534:nogroup:/:/dev/null
EOF

  cat <<EOF > ${rootfs}/etc/group
root:x:0:
nogroup:x:65534:
EOF
  
  tar -cf ${out}/rootfs.tar -C ${rootfs} .  
}

dockerfile() {  
  cat <<EOF > ${out}/Dockerfile
FROM scratch

ADD rootfs.tar /

ENTRYPOINT [ "/bin/haproxy-systemd-wrapper", "-p", "/var/run/haproxy.pid" ]
CMD        [ "-f", "/etc/haproxy.cfg" ]

EOF
}

download
build
dockerfile
