#!/usr/bin/env bash
export PYTHONUNBUFFERED=1

echo "WEBDAV: Starting WebDAV"
echo "WEBDAV: Checking for config..."

if [ ! -f "/workspace/configs/webdav/wsgidav.yaml" ]; then
    echo "WEBDAV: Config not found — creating new config..."

    cat <<EOF >/workspace/configs/webdav/wsgidav.yaml
host: 0.0.0.0
port: 9999

provider_mapping:
  "/": "/workspace"

auth:
  method: htpasswd
  htpasswd_file: /workspace/configs/webdav/.htpasswd
  accept_basic: true
  accept_digest: false
  default_to_anonymous: false

simple_dc:
  user_mapping:
    "*":
      "${FIRST_SUPERUSER_USERNAME}":
        password: "${FIRST_SUPERUSER_PASSWORD}"

middleware_stack:
  - wsgidav.error_printer.ErrorPrinter
  - wsgidav.http_authenticator.HTTPAuthenticator
  - wsgidav.dir_browser.WsgiDavDirBrowser
  - wsgidav.request_resolver.RequestResolver
EOF

    echo "WEBDAV: Config created. Using FIRST_SUPERUSER_USERNAME and FIRST_SUPERUSER_PASSWORD for auth."
else
    echo "WEBDAV: Config already exists"
fi

echo "WEBDAV: Starting WebDAV..."
nohup wsgidav -c /workspace/configs/webdav/wsgidav.yaml \
    >/workspace/.logs/webdav.log 2>&1 &

echo "WEBDAV: WebDAV started — logs: /workspace/.logs/webdav.log"
