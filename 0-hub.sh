#!/bin/bash
makeopts="-j 5"

sysupdate() {
    apt-get update
}

sysdeps() {
    # basic dependencies
    apt-get install -y git python3 python3-pip tmux

    # zflist dependencies
    apt-get install -y build-essential libsnappy-dev libz-dev \
        libtar-dev libb2-dev autoconf libtool libjansson-dev \
        libhiredis-dev libsqlite3-dev libssl-dev locales

    mkdir -p /mnt/hub
}

sysconfig() {
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
}

zhub() {
    git clone https://github.com/threefoldtech/0-hub
    pip3 install -r 0-hub/requirements.txt
}

libcurl() {
    git clone --depth=1 -b curl-7_62_0 https://github.com/curl/curl

    pushd curl
    autoreconf -f -i -s

    ./configure --disable-debug --enable-optimize --disable-curldebug --disable-symbol-hiding --disable-rt \
        --disable-ftp --disable-ldap --disable-ldaps --disable-rtsp --disable-proxy --disable-dict \
        --disable-telnet --disable-tftp --disable-pop3 --disable-imap --disable-smb --disable-smtp --disable-gopher \
        --disable-manual --disable-libcurl-option --disable-sspi --disable-ntlm-wb --without-brotli --without-librtmp --without-winidn \
        --disable-threaded-resolver \
        --with-openssl

    make ${makeopts}
    make install
    ldconfig
    popd
}

capnp() {
    git clone https://github.com/opensourcerouting/c-capnproto

    pushd c-capnproto
    git submodule update --init --recursive
    autoreconf -f -i -s

    ./configure
    make ${makeopts}
    make install
    ldconfig
    popd
}

zflist() {
    git clone https://github.com/threefoldtech/0-flist

    pushd 0-flist
    make

    pushd zflist
    make mrproper
    make production
    cp zflist /usr/local/bin/
    popd

    popd
}

defconfigpatch() {
    cat > /tmp/zhub-config.patch << EOF
--- python/config.py   2019-01-22 11:40:06.639507593 +0000
+++ python/config.py.new       2019-01-22 16:05:22.369982537 +0000
@@ -2,15 +2,19 @@
 # You should adapt this part to your usage
 #
 config = {
-    'backend-internal-host': "my-zdb",
+    'backend-internal-host': "localhost",
     'backend-internal-port': 9900,
     'backend-internal-pass': '',

-    'backend-public-host': "hub.tld",
+    'backend-public-host': "localhost",
     'backend-public-port': 9900,

     'public-website': "https://hub.tld",

+    'userdata-root-path': '/opt/0-hub/public' ,
+    'workdir-root-path': '/opt/0-hub/workdir',
+    'zflist-bin': '/usr/local/bin/zflist',
+
     'ignored-files': ['.', '..', '.keep'],
-    'official-repositories': ['official-apps', 'dockers'],
+    'official-repositories': ['default'],

--- Caddyfile.sample	2019-01-22 16:17:45.981669404 +0000
+++ Caddyfile	2019-01-22 16:25:16.160242072 +0000
@@ -1,14 +1,14 @@
-0.0.0.0:2015
+0.0.0.0:8080

 timeouts 30m

 log stdout
-root public
+root /opt/0-hub/public

 oauth {
-    client_id       __CLIENT_ID__
-    client_secret   __CLIENT_SECRET__
-    redirect_url    http://__HOST__/_iyo_callback
+    client_id       zerohub-demo
+    client_secret   azGLDS0bTKC-OjkQLdoknS1AVTWqB4N4E0AAKuQu1I04BddiuVqP
+    redirect_url    http://localhost:8080/_iyo_callback

     authentication_required    /upload
     authentication_required    /upload-flist
@@ -19,12 +19,12 @@
     api_base_path /api/flist/me
     logout_url /logout

-    extra_scopes user:memberof:__OFFICIAL_ORG__
+    extra_scopes user:memberof:my-super-organization

     forward_payload
     refreshable
 }

-proxy / __PYTHON_HOST__:5000 {
+proxy / localhost:5555 {
 	except /static
 }
EOF
}

defconfig() {
    cp /opt/0-hub/python/config.py.sample /opt/0-hub/python/config.py
    cp /opt/0-hub/Caddyfile.sample /opt/0-hub/Caddyfile

    pushd /opt/0-hub/
    defconfigpatch
    patch -p0 < /tmp/zhub-config.patch
    popd

    mkdir /opt/0-hub/public/users/default
}

caddypatch() {
    cat > /tmp/caddy-oauth.patch << EOF
--- caddyhttp/httpserver/plugin.go	2019-01-22 11:23:27.481333928 +0000
+++ caddyhttp/httpserver/plugin.go.new	2019-01-22 11:23:21.435393387 +0000
@@ -648,6 +648,7 @@
 	"basicauth",
 	"redir",
 	"status",
+	"oauth",
 	"cors",      // github.com/captncraig/cors/caddy
 	"s3browser", // github.com/techknowlogick/caddy-s3browser
 	"nobots",    // github.com/Xumeiquer/nobots
--- caddy/caddymain/run.go	2019-01-22 11:23:27.481333928 +0000
+++ caddy/caddymain/run.go.new	2019-01-22 11:22:39.351807263 +0000
@@ -38,6 +38,8 @@

 	_ "github.com/mholt/caddy/caddyhttp" // plug in the HTTP server type
 	// This is where other plugins get plugged in (imported)
+
+	_ "github.com/itsyouonline/caddy-integration/oauth"
 )

 func init() {
EOF
}

caddy() {
    curl https://storage.googleapis.com/golang/go1.10.3.linux-amd64.tar.gz > /tmp/go1.10.3.linux-amd64.tar.gz
    tar -C /usr/local -xzf /tmp/go1.10.3.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    mkdir -p /tmp/gopath/src
    export GOPATH=/tmp/gopath

    pushd $GOPATH/src
    go get -u github.com/mholt/caddy
    go get -u github.com/caddyserver/builds
    go get -d github.com/itsyouonline/caddy-integration/oauth
    popd

    pushd $GOPATH/src/github.com/mholt/caddy
    caddypatch
    patch -p0 < /tmp/caddy-oauth.patch
    popd

    pushd $GOPATH/src/github.com/mholt/caddy/caddy
    go run build.go -goos=linux -goarch=amd64
    cp caddy /usr/local/bin/
    popd
}

startupscript() {
    cat > /.startup.toml << EOF
[startup.pyhub]
name = "core.system"

[startup.pyhub.args]
name = "/usr/bin/python3"
args = ["/opt/0-hub/python/flist-uploader.py"]

[startup.pyhub.args.env]
LANG = "en_US.UTF-8"

[startup.caddy]
name = "core.system"

[startup.caddy.args]
name = "/usr/local/bin/caddy"
args = ["-conf", "/opt/0-hub/Caddyfile"]

[startup.caddy.args.env]
LANG = "en_US.UTF-8"
EOF
}

clean() {
    rm -rf /usr/local/go
    rm -rf /root/.cache/*
    rm -rf /tmp/*
    rm -rf /var/lib/apt/lists/*
    rm -rf /usr/share/man
    rm -rf /usr/share/doc
    rm -rf /usr/local/share/man
    rm -rf /usr/local/include
    rm -rf /usr/lib/x86_64-linux-gnu/*.a
    rm -rf /usr/lib/*.a
    rm -rf /usr/local/lib/*.a

    apt-get remove -y --purge build-essential binutils python3-pip autoconf git
    apt-get autoremove -y --purge
}

main() {
    set -ex

    sysupdate
    sysdeps
    sysconfig

    pushd /opt
    zhub
    popd

    pushd /tmp
    libcurl
    capnp
    zflist
    caddy
    popd

    startupscript
    defconfig
    clean
}

main
