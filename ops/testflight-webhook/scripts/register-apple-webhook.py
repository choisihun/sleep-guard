#!/usr/bin/env python3

import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt


API_BASE = "https://api.appstoreconnect.apple.com/v1"


def required_env(name):
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"{name} is required")
    return value


def make_token():
    key_id = required_env("ASC_KEY_ID")
    issuer_id = required_env("ASC_ISSUER_ID")
    private_key_path = required_env("ASC_PRIVATE_KEY_PATH")

    with open(private_key_path, "r", encoding="utf-8") as handle:
        private_key = handle.read()

    now = int(time.time())
    return jwt.encode(
        {
            "iss": issuer_id,
            "iat": now,
            "exp": now + 20 * 60,
            "aud": "appstoreconnect-v1",
        },
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def request_json(method, path, token, payload=None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        f"{API_BASE}{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode("utf-8")
            return response.status, json.loads(body) if body else None
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8")
        print(body, file=sys.stderr)
        raise SystemExit(error.code)


def main():
    token = make_token()
    app_id = required_env("ASC_APP_ID")
    webhook_url = required_env("APPLE_WEBHOOK_URL")
    webhook_secret = required_env("APPLE_WEBHOOK_SECRET")
    name = os.environ.get("APPLE_WEBHOOK_NAME", "Sleep Guard TestFlight Telegram")
    events = [
        value.strip()
        for value in os.environ.get(
            "APPLE_WEBHOOK_EVENTS",
            "BUILD_BETA_DETAIL_EXTERNAL_BUILD_STATE_UPDATED",
        ).split(",")
        if value.strip()
    ]

    payload = {
        "data": {
            "type": "webhooks",
            "attributes": {
                "enabled": True,
                "eventTypes": events,
                "name": name,
                "secret": webhook_secret,
                "url": webhook_url,
            },
            "relationships": {
                "app": {
                    "data": {
                        "type": "apps",
                        "id": app_id,
                    }
                }
            },
        }
    }

    status, response = request_json("POST", "/webhooks", token, payload)
    print(json.dumps({"status": status, "response": response}, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
