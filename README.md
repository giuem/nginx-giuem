# Nginx for GIUEM

GIUEM's Nginx build scripts and configuration. 

## Overview

* **Nginx: 1.15.3**
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