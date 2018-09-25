# Nginx for GIUEM

[![Travis (.com)](https://img.shields.io/travis/com/giuem/nginx-giuem.svg?style=flat-square)](https://travis-ci.com/giuem/nginx-giuem)
[![SSLLabs](https://img.shields.io/badge/SSLLabs-A%2B-brightgreen.svg?style=flat-square)](https://www.ssllabs.com/ssltest/analyze.html?d=ssl.giuem.com)
[![GitHub](https://img.shields.io/github/license/giuem/nginx-giuem.svg?style=flat-square)](https://github.com/giuem/nginx-giuem/blob/master/LICENSE)

GIUEM's Nginx build scripts and configuration. 

Test page: [https://ssl.giuem.com](https://ssl.giuem.com)

## Overview

* **Nginx: 1.15.4**
  * SPDY
  * HTTP2 HPACK Encoding
  * Dynamic TLS Record
  * Auto using SSL_OP_PRIORITIZE_CHACHA
* **OpenSSL: 1.1.1**
  * TLS 1.3 (draft 23, 26, 28, final)
  * BoringSSL's Equal Preference Patch
* **Zlib: Cloudflare Mod**
* Pcre: 8.42
* Jemalloc: 5.1.0
* Nginx Modules:
  * ngx_brotli
  * ngx_devel_kit
  * ngx_headers_more
  * ngx_cache_purge
  * ngx_http_echo
* *Some optimizations that have not been tested*

## Supported Distributions

### Ubuntu

* 18.04
* 16.04

More distributions WIP...

## Usage

``` bash
git clone https://github.com/giuem/nginx-giuem.git
cd nginx-giuem
sudo ./install.sh
```

## Credits

* [Cloudflare](https://www.cloudflare.com/)
* [kn007](https://github.com/kn007)
* [Hakase](https://github.com/hakasenyang)
