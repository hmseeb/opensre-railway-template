#!/usr/bin/env bash
# Contract: usage test/contract.sh <image>. Boots the image the way Railway does
# (root, a root-owned volume with lost+found at /data) and checks:
#   - gateway up, /health 200 with an LLM key set
#   - prompt intake reachable and bearer-gated (no token / wrong token = 401)
#   - a correct token queues a prompt (202) and the job reads back
#   - the process runs as uid 1000, state lands on the volume and survives restart
# A fake Anthropic key is enough: this checks wiring, not a model answer.
set -euo pipefail
IMAGE="$1"; NAME="osre-contract-$$"; VOL="osre-contract-vol-$$"; PORT=18000
TOKEN=contract-token-0123456789abcdef
trap 'docker rm -f "$NAME" >/dev/null 2>&1; docker volume rm "$VOL" >/dev/null 2>&1' EXIT
fail() { echo "FAIL: $*"; docker logs "$NAME" 2>&1 | tail -40; exit 1; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
B="http://127.0.0.1:$PORT"

docker volume create "$VOL" >/dev/null
# Railway volumes: root-owned, lost+found at the mount root.
docker run --rm -v "$VOL:/data" --user 0 "$IMAGE" sh -c 'mkdir -p /data/lost+found && chown 0:0 /data && chmod 755 /data'

start() {
  docker run -d --name "$NAME" -p "$PORT:8000" -v "$VOL:/data" \
    -e PORT=8000 -e LLM_PROVIDER=anthropic -e ANTHROPIC_API_KEY=sk-ant-contract-fake \
    -e OPENSRE_GATEWAY_LISTENER_TOKEN="$TOKEN" "$IMAGE" >/dev/null
  for _ in $(seq 1 180); do [ "$(code "$B/readyz")" = 200 ] && return 0; sleep 1; done
  fail "gateway never became ready"
}

start
[ "$(code "$B/healthz")" = 200 ] || fail "/healthz not 200"
[ "$(code "$B/health")" = 200 ] || fail "/health not 200 with an LLM key set"

P='{"prompt":"say hi","request_id":"contract-00000001"}'
[ "$(code -X POST -H 'content-type: application/json' -d "$P" "$B/v1/prompt")" = 401 ] || fail "prompt without token not 401"
[ "$(code -X POST -H 'authorization: Bearer nope' -H 'content-type: application/json' -d "$P" "$B/v1/prompt")" = 401 ] || fail "wrong token not 401"
[ "$(code -X POST -H 'content-type: application/json' -d '{"title":"x"}' "$B/alerts")" = 401 ] || fail "alerts without token not 401"

R="$(curl -s -w '\n%{http_code}' -X POST -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -d "$P" "$B/v1/prompt")"
[ "$(tail -n1 <<<"$R")" = 202 ] || fail "authed prompt not 202: $R"
ID="$(head -n1 <<<"$R" | jq -r '.id // .prompt_id')"
[ -n "$ID" ] && [ "$ID" != null ] || fail "no prompt id in: $R"
[ "$(code -H "authorization: Bearer $TOKEN" "$B/v1/prompt/$ID")" = 200 ] || fail "prompt $ID does not read back"

[ "$(docker exec "$NAME" sh -c 'ps -o uid= -C opensre | head -n1 | tr -d " "')" = 1000 ] || fail "gateway not running as uid 1000"
docker exec "$NAME" sh -c 'test -n "$(ls -A /data/opensre)"' || fail "no state written under /data/opensre"

docker restart "$NAME" >/dev/null
for _ in $(seq 1 180); do [ "$(code "$B/readyz")" = 200 ] && break; sleep 1; done
[ "$(code "$B/readyz")" = 200 ] || fail "not ready after restart"
[ "$(code -H "authorization: Bearer $TOKEN" "$B/v1/prompt/$ID")" = 200 ] || fail "prompt $ID lost across restart"
echo PASS
