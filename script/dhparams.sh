#!/bin/bash
set -e

openssl dhparam -out /etc/nginx/ssl/dhparams.pem 2048