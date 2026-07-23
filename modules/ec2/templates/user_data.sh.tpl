#!/bin/bash
set -euxo pipefail

dnf install -y nginx

# Game HTML arrives base64-encoded so arbitrary quotes/backticks/$() in the
# JS/HTML payload can never be interpreted by this shell script.
echo "${game_html_b64}" | base64 -d > /usr/share/nginx/html/index.html
echo '{"region":"${region_label}"}' > /usr/share/nginx/html/region.json

systemctl enable nginx
systemctl restart nginx
