#!/bin/bash

echo "#Cloudflare" > conf/conf.d/00_real_ip_cloudflare_00.conf;
for i in `curl https://www.cloudflare.com/ips-v4`; do
  echo "set_real_ip_from $i;" >> conf/conf.d/00_real_ip_cloudflare_00.conf;
done
for i in `curl https://www.cloudflare.com/ips-v6`; do
  echo "set_real_ip_from $i;" >> conf/conf.d/00_real_ip_cloudflare_00.conf;
done
echo "real_ip_header CF-Connecting-IP;" >> conf/conf.d/00_real_ip_cloudflare_00.conf;