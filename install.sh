#!/usr/bin/env bash
set -e

NGINX=1.15.3
OPENSSL=1.1.1
PCRE=8.42
JEMALLOC=5.1.0

DIR="$( cd "$( dirname "$0" )" && pwd )/.nginx"
CPUS=$(($(grep -c ^processor /proc/cpuinfo)+1))
MAKE_THREAD=" -j$CPUS "
mkdir -p ${DIR}/patch ${DIR}/lib ${DIR}/src
cd $DIR

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

_install_dependencies() {
    pre_reqs="build-essential cmake autoconf automake git unzip uuid-dev libatomic1 libatomic-ops-dev libgd-dev libtool libgeoip-dev wget" > /dev/null
    apt-get update -q && apt-get install -y -q ${pre_reqs} > /dev/null
    echo "install dependencies done"
}

_download_patch() {
    pushd patch
    git -C hakasenyang pull || git clone https://github.com/hakasenyang/openssl-patch.git hakasenyang
    git -C kn007 pull || git clone https://github.com/kn007/patch.git kn007
    popd
}

_openssl() {
    pushd lib
    if [ ! -d "openssl-${OPENSSL}" ]; then
        # remove old version
        rm -rf openssl-*
        wget -cnv https://www.openssl.org/source/openssl-${OPENSSL}.tar.gz -O openssl-${OPENSSL}.tar.gz && tar zxf openssl-${OPENSSL}.tar.gz && rm openssl-${OPENSSL}.tar.gz && cd openssl-${OPENSSL}
        patch -p1 < ${DIR}/patch/hakasenyang/openssl-equal-${OPENSSL}_ciphers.patch
    fi
    popd
}

_brotli() {
    pushd lib
    git -C ngx_brotli pull ||git clone https://github.com/eustas/ngx_brotli
    cd ngx_brotli && git submodule update --init
    popd
}

_zilb() {
    pushd lib
    git -C zlib pull || git clone https://github.com/cloudflare/zlib
    # cd zlib && ./configure
    popd
}

_pcre() {
    pushd lib
    if [ ! -d pcre-${PCRE} ]; then
        rm -rf pcre-*
        wget -cnv https://ftp.pcre.org/pub/pcre/pcre-${PCRE}.zip && unzip -q pcre-${PCRE}.zip && rm pcre-${PCRE}.zip
        # cd pcre-${PCRE} && cd ../ && rm -rf pcre && mv pcre-${PCRE} pcre
    fi
    popd
}

_jemalloc() {
    pushd lib    
    if [ ! -f '/usr/local/lib/libjemalloc.so' ] || \
        [ $(strings /usr/local/lib/libjemalloc.so | grep -c "JEMALLOC_VERSION \"${JEMALLOC}") = 0 ]; then
        wget -cnv https://github.com/jemalloc/jemalloc/releases/download/${JEMALLOC}/jemalloc-${JEMALLOC}.tar.bz2 && tar xjf jemalloc-${JEMALLOC}.tar.bz2 && rm jemalloc-${JEMALLOC}.tar.bz2 && cd jemalloc-${JEMALLOC}
        ./configure && make ${MAKE_THREAD} && make install
        echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf
        ldconfig && cd ../
    fi
    popd
}

_ngx_ct() {
    pushd lib
    git -C nginx-ct pull || git clone https://github.com/grahamedgecombe/nginx-ct.git
    popd
}

_ngx_devel_kit() {
    pushd lib
    git -C ngx_devel_kit pull || git clone https://github.com/simpl/ngx_devel_kit.git
    popd
}

_ngx_geoip() {
    pushd lib
    add-apt-repository ppa:maxmind/ppa -y
    apt update && apt install libmaxminddb0 libmaxminddb-dev mmdb-bin
    git -C ngx_http_geoip2_module pull || git clone https://github.com/leev/ngx_http_geoip2_module.git
    popd
}

_ngx_header_more() {
    pushd lib
    git -C headers-more-nginx-module pull || git clone https://github.com/openresty/headers-more-nginx-module.git
    popd
}

_ngx_cache_purge() {
    pushd lib
    git -C ngx_cache_purge pull || git clone https://github.com/nginx-modules/ngx_cache_purge.git
    popd
}

_nginx_build() {
    _install_dependencies
    _download_patch

    _openssl
    _brotli
    _zilb
    _pcre
    _jemalloc
    # _ngx_ct
    # _ngx_geoip
    _ngx_devel_kit
    _ngx_header_more
    _ngx_cache_purge

    wget -cnv "https://nginx.org/download/nginx-${NGINX}.tar.gz" -O nginx-${NGINX}.tar.gz && tar zxf nginx-${NGINX}.tar.gz && rm -rf ${DIR}/src nginx-${NGINX}.tar.gz && mv nginx-${NGINX} ${DIR}/src
    pushd src
    patch -p1 < ${DIR}/patch/kn007/nginx.patch
    patch -p1 < ${DIR}/patch/kn007/nginx_auto_using_PRIORITIZE_CHACHA.patch
    # patch -p1 < ${DIR}/patch/hakasenyang/remove_nginx_server_header.patch

    ./configure --build=nginx-giuem \
    --with-cc-opt='-m64 -march=native -DTCP_FASTOPEN=23 -g -O3 -fPIE -fstack-protector-strong -flto -fuse-ld=gold --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wno-unused-parameter -fno-strict-aliasing -fPIC -D_FORTIFY_SOURCE=2 -gsplit-dwarf' \
    --with-ld-opt='-L/usr/local/lib -lrt -ljemalloc -Wl,-Bsymbolic-functions -fPIE -pie -Wl,-z,relro -Wl,-z,now -fPIC' \
    --with-openssl=${DIR}/lib/openssl-${OPENSSL} \
    --with-openssl-opt='enable-ec_nistp_64_gcc_128 enable-weak-ssl-ciphers no-ssl3 -march=native -ljemalloc -Wl,-flto' \
    --with-zlib=${DIR}/lib/zlib \
    --with-zlib-opt='-g -O3 -fPIC -m64 -march=native -fstack-protector-strong -D_FORTIFY_SOURCE=2' \
    --with-pcre=${DIR}/lib/pcre-${PCRE} \
    --with-pcre-opt='-g -O3 -fPIC -m64 -march=native -fstack-protector-strong -D_FORTIFY_SOURCE=2' \
    --with-pcre-jit \
    --prefix=/usr/share/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --http-log-path=/var/log/nginx/access.log \
    --error-log-path=/var/log/nginx/error.log \
    --lock-path=/var/lock/nginx.lock \
    --pid-path=/run/nginx.pid \
    --modules-path=/usr/lib/nginx/modules \
    --http-client-body-temp-path=/var/lib/nginx/body \
    --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
    --http-proxy-temp-path=/var/lib/nginx/proxy \
    --http-scgi-temp-path=/var/lib/nginx/scgi \
    --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
    --user=www-data \
    --group=www-data \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-libatomic \
    --with-poll_module \
    --with-select_module \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_v2_hpack_enc \
    --with-http_spdy_module \
    --with-http_realip_module \
    --with-http_geoip_module \
    --with-http_addition_module \
    --with-http_image_filter_module \
    --with-http_sub_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_degradation_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --without-mail_pop3_module --without-mail_imap_module --without-mail_smtp_module \
    --add-module=${DIR}/lib/ngx_brotli \
    --add-module=${DIR}/lib/headers-more-nginx-module \
    --add-module=${DIR}/lib/ngx_devel_kit \
    --add-module=${DIR}/lib/ngx_cache_purge

    make ${MAKE_THREAD}
    popd
}

_nginx_install() {
    pushd src
    make install
    popd

    mkdir -p /var/lib/nginx/body
    cat > /lib/systemd/system/nginx.service <<EOF
[Unit]
Description=A high performance web server and a reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t 
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT $MAINPID
TimeoutStopSec=5
PrivateTmp=true
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF
    cp -rf conf/* /etc/nginx/
    systemctl enable nginx.service
    systemctl start nginx.service
}

_nginx_upgrade() {
    pushd src
    echo "Upgrade Nginx..."
    mv /usr/sbin/nginx /usr/sbin/nginx.oldbin
    mv objs/nginx /usr/sbin/nginx
    /usr/sbin/nginx -t
    kill -USR2 `cat /run/nginx.pid`
    sleep 1
    test -f /run/nginx.pid.oldbin
    kill -QUIT `cat /run/nginx.pid.oldbin`
    popd
}

_nginx_build
if [ ! -f "/usr/sbin/nginx" ]; then
    _nginx_install
else
    _nginx_upgrade
fi
