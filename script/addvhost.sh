#!/bin/bash

DOMAIN=$1
if [ -e ${DOMAIN} ]; then
    echo "Usage: ./addvhost.sh DOMAIN"
    exit
fi
echo "Add new vhost: ${DOMAIN}"

    cat > /etc/nginx/vhosts/${DOMAIN}.conf <<EOF
server {
    listen               443 ssl http2 spdy; # fastopen=3 reuseport;
    server_name          ${DOMAIN};

    # ECC
    # ssl_certificate      ssl/${DOMAIN}_ecc.cert
    # ssl_certificate_key  ssl/${DOMAIN}_ecc.key;
    # RSA
    # ssl_certificate      ssl/${DOMAIN}.cert
    # ssl_certificate_key  ssl/${DOMAIN}.key;

    include snipatse/tls-1.3.conf;
    # ...
}

server {
    listen 80;
    server_name ${DOMAIN};
    access_log off;
    return 301 https://\$server_name\$request_uri;
}
EOF

echo "Done"