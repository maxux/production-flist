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

    cp /bin/bash ${ICECAST_ROOT}/bin/
    ./lddcopy.sh ${ICECAST_ROOT}/bin/bash ${ICECAST_ROOT}

    # symlink /bin/sh to bash
    pushd ${ICECAST_ROOT}/bin/
    ln -s bash sh
    popd

    cp /bin/sed ${ICECAST_ROOT}/bin/
    ./lddcopy.sh ${ICECAST_ROOT}/bin/sed ${ICECAST_ROOT}
}

config() {
    mkdir -p -m 777 ${ICECAST_ROOT}/tmp
    mkdir -p -m 777 ${ICECAST_ROOT}/var/log

    cp /etc/mime.types ${ICECAST_ROOT}/etc/

    # add icecast user and group
    echo "root:x:0:0:root:/root:/bin/bash" > ${ICECAST_ROOT}/etc/passwd
    echo "icecast:x:1000:1000:icecast:/root:/bin/bash" >> ${ICECAST_ROOT}/etc/passwd

    echo "root:x:0:root" > ${ICECAST_ROOT}/etc/group
    echo "icecast:x:1000:icecast" >> ${ICECAST_ROOT}/etc/group

    # change customizable settings
    sed -i "s/location>Earth/location>__location__/" ${ICECAST_ROOT}/etc/icecast.xml
    sed -i "s/icemaster@localhost/__admin__/" ${ICECAST_ROOT}/etc/icecast.xml
    sed -i "s/hostname>localhost/hostname>__hostname__/" ${ICECAST_ROOT}/etc/icecast.xml
    sed -i "s/hackme/__password__/g" ${ICECAST_ROOT}/etc/icecast.xml

    # change logs path
    sed -i "s#//var/log/icecast#//var/log/#" ${ICECAST_ROOT}/etc/icecast.xml

    # uncomment ownerchange section
    sed -i '237d' ${ICECAST_ROOT}/etc/icecast.xml
    sed -i '241d' ${ICECAST_ROOT}/etc/icecast.xml

    # set owner
    sed -i "s/user>nobody/user>icecast/" ${ICECAST_ROOT}/etc/icecast.xml
    sed -i "s/group>nogroup/group>icecast/" ${ICECAST_ROOT}/etc/icecast.xml
}

startup() {
    cat > ${ICECAST_ROOT}/bin/launcher << EOF
#!/bin/bash
cfg_password="${ICECAST_PASSWORD:-donothackme}"
cfg_location="${ICECAST_LOCATION:-Zero OS}"
cfg_admin="${ICECAST_ADMIN:-root@zero-os-icecast.net}"
cfg_hostname="${ICECAST_HOSTNAME:-zero-os-icecast}"

sed -i "s/__location__/${cfg_location}/g" /etc/icecast.xml
sed -i "s/__admin__/${cfg_admin}/g" /etc/icecast.xml
sed -i "s/__hostname__/${cfg_hostname}/g" /etc/icecast.xml
sed -i "s/__password__/${cfg_password}/g" /etc/icecast.xml

/bin/icecast -c /etc/icecast.xml
EOF

    cat > ${ICECAST_ROOT}/.startup.toml << EOF
[startup.icecast]
name = "bash"

[startup.icecast.args]
script = "/bin/launcher"
EOF

    chmod +x ${ICECAST_ROOT}/bin/launcher
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
    startup
    cleanup
    archive
}

main
