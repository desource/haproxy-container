#!/usr/bin/env bash
#
# Download and build haproxy container
set -euo pipefail

src=$PWD/src
out=$PWD/out
rootfs=$PWD/rootfs

container=$PWD/container

slz=$PWD/libslz
libressl=$PWD/libressl

_init() {
  apk add --no-cache --no-progress \
      autoconf \
      automake \
      bash \
      cmake \
      curl \
      gcc \
      git \
      gnupg1 \
      libc-dev \
      libtool \
      linux-headers \
      make \
      pcre-dev \
      perl \
      readline-dev \
      tar \
      xz-dev \
      zlib-dev
}

# _download "version" "sha256"
_download() {
  mkdir -p ${src}
  curl -OL http://www.haproxy.org/download/1.6/src/haproxy-${1}.tar.gz
  echo "${2}  haproxy-${1}.tar.gz" | sha256sum -c
  tar -C ${src} --strip-components 1 -xf haproxy-${1}.tar.gz

  cat <<EOF > ${out}/version
${1}
EOF
}

_build() {
  cd ${src}
  make TARGET=linux2628 \
         USE_TFO=1 \
         CPU=native CPU_CFLAGS.native=-O3 \
         USE_PCRE_JIT=1 \
         ADDLIB="-static -L${slz}/lib" USE_SLZ=1 ADDINC=-I${slz}/include \
         USE_OPENSSL=1 SSL_LIB=${libressl}/lib SSL_INC=${libressl}/include

  mkdir -p ${rootfs}/bin ${rootfs}/var/run/haproxy

  cp haproxy haproxy-systemd-wrapper ${rootfs}/bin

  cp -r ${container}/etc ${rootfs}

  cat <<EOF > ${rootfs}/etc/passwd
root:x:0:0:root:/:/dev/null
nobody:x:65534:65534:nobody:/:/dev/null
EOF

  cat <<EOF > ${rootfs}/etc/group
root:x:0:
nobody:x:65534:
EOF

  tar -cf ${out}/rootfs.tar -C ${rootfs} .
}

# _dockerfile "version"
_dockerfile() {
  cat <<EOF > ${out}/Dockerfile
FROM scratch

ADD rootfs.tar /

ENTRYPOINT [ "/bin/haproxy-systemd-wrapper", "-p", "/var/run/haproxy.pid" ]
CMD        [ "-f", "/etc/haproxy.cfg" ]

EOF
}

_init
_download 1.7.3 ebb31550a5261091034f1b6ac7f4a8b9d79a8ce2a3ddcd7be5b5eb355c35ba65
_build
_dockerfile
