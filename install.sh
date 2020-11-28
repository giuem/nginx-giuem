#!/usr/bin/env bash
set -e

# sed -i 's/archive.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list

NGINX=1.17.6
OPENSSL=1.1.1f
PCRE=8.43
JEMALLOC=5.2.1

DIR="$( cd "$( dirname "$0" )" && pwd )/.nginx"
CPUS=$(($(grep -c ^processor /proc/cpuinfo)+1))
MAKE_THREAD=" -j$CPUS "
NGINX_MODULES=""
mkdir -p ${DIR}/patch ${DIR}/lib ${DIR}/src
cd $DIR

get_distribution() {
    lsb_dist=""
    if [ -r /etc/os-release ]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
    fi
    echo "$lsb_dist"
}

lsb_dist=$( get_distribution )
lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

sync_git_repo () {
    if [ ! -d $1 ]; then
        return 128
    fi
    pushd $1
    git fetch && git reset --hard origin/master
    popd
}

_install_dependencies() {
    case "$lsb_dist" in
    ubuntu)
        pre_reqs="build-essential cmake autoconf automake git unzip uuid-dev libatomic1 libatomic-ops-dev libgd-dev libtool libgeoip-dev wget"
        apt-get update -qq > /dev/null
        apt-get install -y -qq ${pre_reqs} > /dev/null
    ;;
    centos)
        pre_reqs="gcc gcc-c++ make cmake patch autoconf automake git unzip libuuid-devel libatomic libatomic_ops-devel wget libtool libmaxminddb-devel gd-devel geoip-devel bzip2"
        yum install -y -q ${pre_reqs}
    ;;
    *)
        echo "Unsupported distro"
        exit 1
    ;;
    esac
    echo "install dependencies done"
}

_download_patch() {
    pushd patch
    sync_git_repo hakasenyang || git clone https://github.com/hakasenyang/openssl-patch.git hakasenyang
    sync_git_repo kn007 || git clone https://github.com/kn007/patch.git kn007
    popd
}

_openssl() {
    pushd lib
    rm -rf openssl-*
    wget -cnv https://www.openssl.org/source/openssl-${OPENSSL}.tar.gz -O openssl-${OPENSSL}.tar.gz
    tar zxf openssl-${OPENSSL}.tar.gz
    rm openssl-${OPENSSL}.tar.gz
    pushd openssl-${OPENSSL}
    # patch -p1 < ${DIR}/patch/hakasenyang/openssl-equal-${OPENSSL}_ciphers.patch
    patch -p1 < ${DIR}/patch/hakasenyang/openssl-${OPENSSL}-chacha_draft.patch
    popd
    popd
}

_brotli() {
    pushd lib
    sync_git_repo ngx_brotli || git clone https://github.com/google/ngx_brotli
    pushd ngx_brotli
    git submodule update --init
    popd
    popd
    NGINX_MODULES="${NGINX_MODULES} --add-module=${DIR}/lib/ngx_brotli"
}

_zilb() {
    pushd lib
    sync_git_repo zlib || git clone https://github.com/cloudflare/zlib
    pushd zlib
    ./configure --64
    popd
    popd
}

_pcre() {
    pushd lib
    if [ ! -d pcre-${PCRE} ]; then
        rm -rf pcre-*
        wget -cnv https://ftp.pcre.org/pub/pcre/pcre-${PCRE}.zip
        unzip -q pcre-${PCRE}.zip
        rm pcre-${PCRE}.zip
        # cd pcre-${PCRE} && cd ../ && rm -rf pcre && mv pcre-${PCRE} pcre
    fi
    popd
}

_jemalloc() {
    pushd lib    
    if [ ! -f '/usr/local/lib/libjemalloc.so' ] || \
        [ $(strings /usr/local/lib/libjemalloc.so | grep -c "JEMALLOC_VERSION \"${JEMALLOC}") = 0 ]; then
        wget -cnv https://github.com/jemalloc/jemalloc/releases/download/${JEMALLOC}/jemalloc-${JEMALLOC}.tar.bz2
        tar xjf jemalloc-${JEMALLOC}.tar.bz2
        rm jemalloc-${JEMALLOC}.tar.bz2
        pushd jemalloc-${JEMALLOC}
        ./configure
        make ${MAKE_THREAD} > /dev/null
        make install
        echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf
        ldconfig
        popd
    fi
    popd
}

_ngx_ct() {
    pushd lib
    sync_git_repo nginx-ct || git clone https://github.com/grahamedgecombe/nginx-ct.git
    popd
    NGINX_MODULES="${NGINX_MODULES} --add-module=${DIR}/lib/ngx-ct"
}

_ngx_devel_kit() {
    pushd lib
    sync_git_repo ngx_devel_kit || git clone https://github.com/simpl/ngx_devel_kit.git
    popd
    NGINX_MODULES="${NGINX_MODULES} --add-module=${DIR}/lib/ngx_devel_kit"
}

_ngx_geoip() {
    pushd lib
    add-apt-repository ppa:maxmind/ppa -y
    apt-get update -qq > /dev/null
    apt-get install libmaxminddb0 libmaxminddb-dev mmdb-bin -y -qq > /dev/null
    sync_git_repo ngx_http_geoip2_module || git clone https://github.com/leev/ngx_http_geoip2_module.git
    popd
    NGINX_MODULES="${NGINX_MODULES} --add-module=${DIR}/lib/ngx_http_geoip2_module"
}

_ngx_header_more() {
    pushd lib
    sync_git_repo headers-more-nginx-module || git clone https://github.com/openresty/headers-more-nginx-module.git
    popd
    NGINX_MODULES="${NGINX_MODULES} --add-module=${DIR}/lib/headers-more-nginx-module"
}

_ngx_cache_purge() {
    pushd lib
    sync_git_repo ngx_cache_purge || git clone https://github.com/nginx-modules/ngx_cache_purge.git
    popd
    NGINX_MODULES="${NGINX_MODULES} --add-module=${DIR}/lib/ngx_cache_purge"
}

_ngx_echo() {
    pushd lib
    sync_git_repo echo-nginx-module || git clone https://github.com/openresty/echo-nginx-module.git
    popd
    NGINX_MODULES="${NGINX_MODULES} --add-module=${DIR}/lib/echo-nginx-module"
}

_nginx_build() {
    groups www-data > /dev/null || (groupadd www-data && useradd -g www-data www-data)

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
    _ngx_echo

    wget -cnv "https://nginx.org/download/nginx-${NGINX}.tar.gz" -O nginx-${NGINX}.tar.gz
    tar zxf nginx-${NGINX}.tar.gz
    rm -rf ${DIR}/src nginx-${NGINX}.tar.gz
    mv nginx-${NGINX} ${DIR}/src
    pushd src
    patch -p1 < ${DIR}/patch/kn007/nginx.patch
    patch -p1 < ${DIR}/patch/hakasenyang/nginx_strict-sni_1.15.10.patch
    # patch -p1 < ${DIR}/patch/hakasenyang/nginx_hpack_push_fix.patch
    # patch -p1 < ${DIR}/patch/hakasenyang/remove_nginx_server_header.patch

    ./configure --build=nginx-giuem \
    --with-cc-opt='-m64 -march=native -DTCP_FASTOPEN=23 -g -O3 -fPIE -fstack-protector-strong -flto -fuse-ld=gold --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wno-unused-parameter -fno-strict-aliasing -fPIC -D_FORTIFY_SOURCE=2 -gsplit-dwarf' \
    --with-ld-opt='-L/usr/local/lib -lrt -ljemalloc -Wl,-Bsymbolic-functions -fPIE -pie -Wl,-z,relro -Wl,-z,now -fPIC' \
    --with-openssl=${DIR}/lib/openssl-${OPENSSL} \
    --with-openssl-opt='zlib enable-ec_nistp_64_gcc_128 enable-weak-ssl-ciphers no-ssl3 -march=native -ljemalloc -Wl,-flto' \
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
    ${NGINX_MODULES}

    make ${MAKE_THREAD} > /dev/null
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
    yes | cp -rf ../conf/* /etc/nginx/
    /usr/sbin/nginx -t
    echo "Installed, run following commands to start Nginx:"
    echo "systemctl enable nginx.service"
    echo "systemctl start nginx.service"
}

_nginx_upgrade() {
    echo "Upgrade Nginx..."
    mv /usr/sbin/nginx /usr/sbin/nginx.oldbin
    mv src/objs/nginx /usr/sbin/nginx
    cp -irf ../conf/* /etc/nginx/
    /usr/sbin/nginx -t
    kill -USR2 `cat /run/nginx.pid`
    sleep 1
    test -f /run/nginx.pid.oldbin
    kill -QUIT `cat /run/nginx.pid.oldbin`
}

_nginx_build
if [ ! -f "/usr/sbin/nginx" ]; then
    _nginx_install
else
    read -r -p "Do you want to upgrade Nginx? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            _nginx_upgrade
            ;;
        *)
            ;;
    esac
fi
