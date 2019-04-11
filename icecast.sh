#!/bin/bash
set -ex

ICECAST_VERSION="2.4.4"
ICECAST_ROOT="/tmp/icecast-root"

earlystage() {
    apt-get update
    apt-get install -y wget curl build-essential \
        libssl-dev libxslt1-dev libvorbis-dev libogg-dev libspeex-dev libtheora-dev libcurl4-openssl-dev
}

download() {
    cd /tmp
    wget http://downloads.xiph.org/releases/icecast/icecast-${ICECAST_VERSION}.tar.gz
}

extract() {
    cd /tmp
    tar -xvf icecast-${ICECAST_VERSION}.tar.gz
}

compile() {
    cd /tmp/icecast-${ICECAST_VERSION}
    ./configure --prefix=/
    make -j 5
    make DESTDIR=${ICECAST_ROOT} install
}

dependencies() {
    cd /tmp
    wget https://raw.githubusercontent.com/maxux/lddcopy/master/lddcopy.sh
    chmod +x lddcopy.sh

    ./lddcopy.sh ${ICECAST_ROOT}/bin/icecast ${ICECAST_ROOT}
}

config() {
    mkdir -m 777 ${ICECAST_ROOT}/tmp

    mkdir -p -m 755 ${ICECAST_ROOT}/var/log
    chown 1000 -R ${ICECAST_ROOT}/var/log

    cp /etc/mime.types ${ICECAST_ROOT}/etc/

    echo "root:x:0:0:root:/root:/bin/bash" > ${ICECAST_ROOT}/etc/passwd
    echo "icecast:x:1000:1000:icecast:/root:/bin/bash" >> ${ICECAST_ROOT}/etc/passwd

    echo "root:x:0:root" > ${ICECAST_ROOT}/etc/group
    echo "icecast:x:1000:icecast" >> ${ICECAST_ROOT}/etc/group

    sed -i "s/location>Earth/location>Zero-OS Streaming/" ${ICECAST_ROOT}/etc/icecast.xml
    sed -i "s/icemaster@localhost/root@zero-os-icecast.net/" ${ICECAST_ROOT}/etc/icecast.xml
    sed -i "s/hostname>localhost/hostname>zero-os-icecast/" ${ICECAST_ROOT}/etc/icecast.xml

    sed -i "s/hackme/donothackme/g" ${ICECAST_ROOT}/etc/icecast.xml
    sed -i "s/user>nobody/user>icecast/" ${ICECAST_ROOT}/etc/icecast.xml
    sed -i "s/group>nogroup/group>icecast/" ${ICECAST_ROOT}/etc/icecast.xml

    sed -i "s#//var/log/icecast#//var/log/#" ${ICECAST_ROOT}/etc/icecast.xml

    sed -i '237d' ${ICECAST_ROOT}/etc/icecast.xml
    sed -i '241d' ${ICECAST_ROOT}/etc/icecast.xml
}

startup() {
    cat > /.startup.toml << EOF
[startup.icecast]
name = "bash"

[startup.icecast.args]
script = "icecast -c /etc/icecast.xml"
EOF
}

cleanup() {
    rm -rf ${ICECAST_ROOT}/share/doc
}

archive() {
    tar -cpvf /tmp/icecast-root.tar.gz -C ${ICECAST_ROOT} .
    ls -alh /tmp/icecast-root.tar.gz
}

main() {
    earlystage
    download
    extract
    compile
    dependencies
    config
    cleanup
    archive
}

main