#!/bin/sh
# Railway volumes mount root-owned with a lost+found at the root. OpenSRE runs
# as uid 1000 (upstream's choice), so: create the state dir one level below the
# mount, hand it to uid 1000, then drop privileges and exec the gateway.
set -eu

: "${OPENSRE_HOME:=/data/opensre}"
export OPENSRE_HOME

if [ "$(id -u)" = 0 ]; then
  mkdir -p "$OPENSRE_HOME"
  chown -R 1000:1000 "$OPENSRE_HOME"
  exec setpriv --reuid=1000 --regid=1000 --init-groups -- "$0" "$@"
fi

if [ -z "${OPENSRE_GATEWAY_LISTENER_TOKEN:-}" ]; then
  echo "warning: OPENSRE_GATEWAY_LISTENER_TOKEN is empty; /alerts and /v1/prompt refuse every non-local caller" >&2
fi

cd /workspace
exec opensre gateway start --foreground
