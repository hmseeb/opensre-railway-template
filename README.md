# OpenSRE on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/opensre)

One-service Railway template for the [OpenSRE](https://github.com/Tracer-Cloud/opensre) gateway: the AI SRE agent's HTTP prompt API, scheduler and optional Telegram/Slack/Discord chat, with state on a volume.

Deployer guide: [TEMPLATE_OVERVIEW.md](TEMPLATE_OVERVIEW.md) (also the marketplace listing).

## What is in this repo

| Path | Purpose |
|---|---|
| `template.json` | Build sheet and regeneration master. Every choice is annotated with `$note`. |
| `image/` | `ghcr.io/hmseeb/opensre-railway:<version>`: upstream's toolchain plus the pinned release binary, and an entrypoint that hands the root-owned volume to uid 1000. |
| `test/contract.sh` | Boots the image like Railway does and checks readiness, bearer auth, prompt queueing, uid, volume state and restart persistence. Gates the GHCR push in CI. |
| `upsert.py` | `template.json` to Railway template (`templateUpsertConfig`), with field-by-field read-back. |
| `deploy_as_stranger.py` | `templateDeployV2` into a fresh project, the way the deploy button does. |
| `publish.py` | Icon, description, listing copy, publish. |

## Why not upstream's image

Upstream's `Dockerfile` installs the rolling `main` binary at every container start into a path that is not on the volume. On Railway that means a re-download on each restart and a version that drifts with upstream `main`. Upstream's own GHCR image was last pushed 2026-07-28. This image bakes one pinned release instead.

## Upgrading

1. Bump `OPENSRE_VERSION` in `image/Dockerfile` and both tags in `.github/workflows/image.yml`.
2. Push. CI builds, runs the contract test, and pushes only on green.
3. Change the image tag in `template.json` and run `python3 upsert.py`.

## Verified (2026-11-20, template deployed as a stranger)

- Deploy to SUCCESS in about 40 seconds, `/readyz` healthcheck.
- Public URL: `/health` reports `llm_configured: true`; `/v1/prompt` without or with a wrong token returns 401.
- A real agent turn on Anthropic through `POST /v1/prompt` and `GET /v1/prompt/<id>` returned `state: done` with an answer.
- After a restart: `previous_shutdown: clean`, the session and the earlier prompt result were still there.

Not verified live: Telegram, Slack and Discord chat, and investigations that call real observability integrations.

## Known upstream behavior

`POST /alerts` returns 202, but in gateway mode nothing drains that queue (only the interactive shell does, `surfaces/interactive_shell/controller.py`). Use `POST /v1/prompt` for webhook-driven investigations.
