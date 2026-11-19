# Deploy and Host OpenSRE on Railway

OpenSRE is an open-source AI SRE agent from Tracer. It investigates incidents, reads your observability stack (Grafana, Datadog, Honeycomb, Sentry, AWS, Kubernetes and more), and answers with a root cause. This template runs the OpenSRE gateway as one always-on service with a private HTTP prompt API, optional Telegram chat, and a persistent volume for sessions, memory and scheduled tasks.

## About Hosting OpenSRE

The gateway is a long-running process: it serves the HTTP API, runs scheduled checks, and holds chat connections open. Locally that is a laptop that sleeps. On Railway it is one container with a volume at `/data`, a public HTTPS URL, and a bearer token generated for you at deploy time. The image bakes a pinned OpenSRE release (0.1.2026.11.19), so restarts do not re-download the binary or drift onto a newer build.

## Common Use Cases

- Send an alert's text to the agent from your alerting pipeline and get a root-cause write-up back over HTTP
- Chat with the agent from Telegram about a live incident, from your phone
- Run scheduled reliability checks against your Grafana, Datadog or CloudWatch data
- Give a team one shared agent with its own memory instead of a CLI on every laptop

## Dependencies for OpenSRE Hosting

- An LLM API key: Anthropic, OpenAI or OpenRouter on the deploy form, or any other provider OpenSRE supports via variables
- Optional: a Telegram bot token for chat
- Optional: read-only credentials for the observability tools you want it to query

### Deployment Dependencies

- OpenSRE: https://github.com/Tracer-Cloud/opensre
- Docs: https://www.opensre.com/docs
- Image source: https://github.com/hmseeb/opensre-railway-template

### Implementation Details

**On the deploy form**

| Variable | What to put |
|---|---|
| `LLM_PROVIDER` | `anthropic` (default), `openai`, `openrouter`, `gemini`, `deepseek`, `groq`... |
| `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` / `OPENROUTER_API_KEY` | The key for the provider you picked. The others can stay empty. |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS` | Optional. Bot token from @BotFather and your numeric user ID from @userinfobot. |

`OPENSRE_GATEWAY_LISTENER_TOKEN` is generated for you. Copy it from the service's **Variables** tab.

**After deploy**

Open `https://<your-domain>/health`. `"llm_configured": true` means the key landed. If it says `false`, the provider or key is wrong; fix the variable and redeploy.

Ask the agent something:

```bash
TOKEN=<OPENSRE_GATEWAY_LISTENER_TOKEN>
URL=https://<your-domain>

curl -s -X POST "$URL/v1/prompt" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"prompt": "checkout-api p95 latency is 2.1s for 5 minutes. What should I check first?"}'
# -> {"prompt_id":"p_...","state":"queued"}

curl -s "$URL/v1/prompt/p_..." -H "Authorization: Bearer $TOKEN"
# -> {"state":"done","answer":"...","conversation_id":"..."}
```

Follow-ups continue the same conversation by default. Send `"conversation": "new"` for a fresh one, or pass an earlier `conversation_id`. A prompt that stops to ask a question is answered with `POST /v1/prompt/<id>/answer` and `{"answer": "..."}`.

**Wiring alerts in.** Point your alerting webhook (Alertmanager, Grafana, PagerDuty, a small script) at `POST /v1/prompt` with the alert text as `prompt`. Use `POST /v1/prompt`, not `POST /alerts`: on a server, `/alerts` accepts the payload but only the interactive OpenSRE shell reads that queue, so nothing investigates it.

**Connecting your tools.** Add the integration's variables to the service, for example `GRAFANA_INSTANCE_URL` + `GRAFANA_READ_TOKEN`, `DD_API_KEY` + `DD_APP_KEY`, or AWS credentials. The full list is in upstream's `.env.example`. Use read-only credentials.

**Other chat surfaces.** Slack (Socket Mode: `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`, `SLACK_ALLOWED_USERS`) and Discord (`DISCORD_BOT_TOKEN`, `DISCORD_ALLOWED_USERS`) can be added the same way. The boot log lists every surface and why it is or is not enabled.

**Security.** Every route that runs the agent needs the bearer token. Without it the gateway answers 401. Anyone holding the token can run the agent with your LLM key and every integration credential you add, so treat it like a password. To rotate it, change the variable and redeploy.

**Telemetry.** Upstream sends anonymous product analytics and error reports by default. Set `DO_NOT_TRACK=1` to turn both off.

**Storage and scaling.** Sessions, memory, scheduled tasks and the prompt log live in `/data/opensre` on the volume and survive restarts and redeploys. Run one replica: the state is local to the volume.

**Upgrading.** The image is pinned. Newer releases land as new image tags in the template repo; change the service image to upgrade.

**Troubleshooting**

- `/health` returns 503: no usable LLM key. `/readyz` still returns 200, so the service stays up while you fix it.
- `{"error":"unauthorized"}`: the `Authorization` header must be exactly `Bearer <token>`.
- Boot log warns that "network egress is blocked for sandboxed code": expected. Code the agent runs in its own sandbox has no network; integrations make the HTTP calls.

## Why Deploy OpenSRE on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpenSRE on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
