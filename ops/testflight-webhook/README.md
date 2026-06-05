# Sleep Guard TestFlight Webhook

Small Node.js receiver for App Store Connect webhooks. It validates Apple's
`x-apple-signature` HMAC header and forwards TestFlight status changes to
Telegram.

## Required secrets

- `APPLE_WEBHOOK_SECRET`: Random shared secret registered in App Store Connect.
- `TELEGRAM_BOT_TOKEN`: Token from Telegram BotFather.
- `TELEGRAM_CHAT_ID`: Chat ID that should receive alerts.

## Telegram setup

1. In Telegram, open `@BotFather`.
2. Send `/newbot`.
3. Use a name like `Sleep Guard Review`.
4. Use a unique username ending in `bot`, for example `sleep_guard_sihun_review_bot`.
5. Send `/start` to the new bot.
6. Run `TELEGRAM_BOT_TOKEN=... node scripts/telegram-chat-id.js` to get the chat ID.

## Local verification

```sh
node --check server.js
APPLE_WEBHOOK_SECRET=secret node server.js
```

In another shell:

```sh
payload='{"data":{"type":"webhookPings"}}'
signature=$(printf "%s" "$payload" | APPLE_WEBHOOK_SECRET=secret node scripts/apple-sign-sample.js)
curl -i -X POST http://127.0.0.1:3041/apple/app-store-connect \
  -H "content-type: application/json" \
  -H "x-apple-signature: $signature" \
  --data "$payload"
```

## Apple webhook event

Register this event for TestFlight external review status:

```text
BUILD_BETA_DETAIL_EXTERNAL_BUILD_STATE_UPDATED
```

## Deployment

Install Node.js on the target host, create a dedicated `sleepguard` system user,
copy `.env.example` to `/opt/sleepguard-webhook/.env`, and fill in real secrets.

Deploy files:

```sh
scripts/deploy-to-pi.sh user@host /opt/sleepguard-webhook
```

Install the systemd unit on the target host:

```sh
sudo cp sleepguard-webhook.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now sleepguard-webhook.service
```
