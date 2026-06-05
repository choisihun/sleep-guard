#!/usr/bin/env node

const crypto = require("node:crypto");
const http = require("node:http");
const https = require("node:https");
const { URLSearchParams } = require("node:url");

const config = {
  port: Number(process.env.PORT || 3041),
  appleSecret: process.env.APPLE_WEBHOOK_SECRET || "",
  telegramBotToken: process.env.TELEGRAM_BOT_TOKEN || "",
  telegramChatId: process.env.TELEGRAM_CHAT_ID || "",
  telegramThreadId: process.env.TELEGRAM_THREAD_ID || "",
  testflightPublicLink: process.env.TESTFLIGHT_PUBLIC_LINK || "",
  maxBodyBytes: Number(process.env.MAX_BODY_BYTES || 1024 * 1024),
};

const stateLabels = {
  WAITING_FOR_REVIEW: "심사 대기",
  IN_REVIEW: "심사 중",
  REJECTED: "반려",
  APPROVED: "승인",
  BETA_APPROVED: "외부 테스트 승인",
  BETA_REJECTED: "외부 테스트 반려",
  IN_BETA_TESTING: "외부 테스트 가능",
  READY_FOR_BETA_TESTING: "베타 테스트 준비 완료",
  MISSING_EXPORT_COMPLIANCE: "수출 규정 정보 필요",
  IN_EXPORT_COMPLIANCE_REVIEW: "수출 규정 심사 중",
  PROCESSING: "처리 중",
  PROCESSING_EXCEPTION: "처리 실패",
  EXPIRED: "만료",
};

function jsonResponse(res, statusCode, body) {
  const payload = JSON.stringify(body);
  res.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(payload),
  });
  res.end(payload);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;

    req.on("data", (chunk) => {
      total += chunk.length;
      if (total > config.maxBodyBytes) {
        reject(new Error("request body too large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });

    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

function constantTimeEqual(a, b) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

function verifyAppleSignature(rawBody, signatureHeader) {
  if (!config.appleSecret || !signatureHeader) {
    return false;
  }

  const digest = crypto
    .createHmac("sha256", config.appleSecret)
    .update(rawBody)
    .digest("hex");
  const expected = `hmacsha256=${digest}`;

  return String(signatureHeader)
    .split(",")
    .map((value) => value.trim())
    .some((value) => constantTimeEqual(value, expected));
}

function labelForState(state) {
  if (!state) {
    return "알 수 없음";
  }
  return stateLabels[state] ? `${stateLabels[state]} (${state})` : state;
}

function resourceLine(payload) {
  const instance = payload?.data?.relationships?.instance?.data;
  if (!instance?.type || !instance?.id) {
    return null;
  }
  return `${instance.type} / ${instance.id}`;
}

function formatTelegramMessage(payload) {
  const data = payload?.data || {};
  const attributes = data.attributes || {};
  const type = data.type || "unknown";

  if (type === "webhookPings" || type === "webhookPing" || type === "webhookPingCreated") {
    return [
      "Sleep Guard TestFlight 웹훅 테스트 수신",
      `시간: ${new Date().toISOString()}`,
    ].join("\n");
  }

  const newState =
    attributes.newExternalBuildState ||
    attributes.newState ||
    attributes.newValue;
  const oldState =
    attributes.oldExternalBuildState ||
    attributes.oldState ||
    attributes.oldValue;
  const timestamp = attributes.timestamp || new Date().toISOString();
  const resource = resourceLine(payload);

  const lines = [
    "Sleep Guard TestFlight 상태 변경",
    `이벤트: ${type}`,
    `상태: ${labelForState(newState)}`,
  ];

  if (oldState) {
    lines.push(`이전: ${labelForState(oldState)}`);
  }

  lines.push(`시간: ${timestamp}`);

  if (resource) {
    lines.push(`리소스: ${resource}`);
  }

  if (newState === "BETA_APPROVED" || newState === "APPROVED") {
    lines.push("결과: 외부 테스터에게 배포 가능");
    if (config.testflightPublicLink) {
      lines.push(`공개 링크: ${config.testflightPublicLink}`);
    }
  } else if (newState === "BETA_REJECTED" || newState === "REJECTED") {
    lines.push("결과: 반려됨. App Store Connect에서 사유 확인 필요");
  }

  return lines.join("\n");
}

function sendTelegramMessage(text) {
  if (!config.telegramBotToken || !config.telegramChatId) {
    return Promise.reject(new Error("Telegram bot token or chat id is not configured"));
  }

  const payload = new URLSearchParams({
    chat_id: config.telegramChatId,
    text,
    disable_web_page_preview: "true",
  });

  if (config.telegramThreadId) {
    payload.set("message_thread_id", config.telegramThreadId);
  }

  const options = {
    method: "POST",
    hostname: "api.telegram.org",
    path: `/bot${config.telegramBotToken}/sendMessage`,
    headers: {
      "content-type": "application/x-www-form-urlencoded",
      "content-length": Buffer.byteLength(payload.toString()),
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => {
        const body = Buffer.concat(chunks).toString("utf8");
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(body);
        } else {
          reject(new Error(`Telegram API returned ${res.statusCode}: ${body}`));
        }
      });
    });

    req.on("error", reject);
    req.end(payload.toString());
  });
}

async function handleWebhook(req, res) {
  let rawBody;
  try {
    rawBody = await readBody(req);
  } catch (error) {
    jsonResponse(res, 413, { ok: false, error: error.message });
    return;
  }

  if (!verifyAppleSignature(rawBody, req.headers["x-apple-signature"])) {
    jsonResponse(res, 401, { ok: false, error: "invalid apple signature" });
    return;
  }

  let payload;
  try {
    payload = JSON.parse(rawBody.toString("utf8"));
  } catch {
    jsonResponse(res, 400, { ok: false, error: "invalid json" });
    return;
  }

  const eventType = payload?.data?.type || "unknown";
  const message = formatTelegramMessage(payload);

  try {
    await sendTelegramMessage(message);
    console.log(JSON.stringify({ level: "info", eventType, delivered: true }));
    jsonResponse(res, 200, { ok: true });
  } catch (error) {
    console.error(JSON.stringify({ level: "error", eventType, error: error.message }));
    jsonResponse(res, 502, { ok: false, error: "telegram delivery failed" });
  }
}

const server = http.createServer((req, res) => {
  if (req.method === "GET" && req.url === "/healthz") {
    jsonResponse(res, 200, {
      ok: true,
      telegramConfigured: Boolean(config.telegramBotToken && config.telegramChatId),
      appleSecretConfigured: Boolean(config.appleSecret),
    });
    return;
  }

  if (req.method === "POST" && req.url === "/apple/app-store-connect") {
    handleWebhook(req, res).catch((error) => {
      console.error(JSON.stringify({ level: "error", error: error.message }));
      jsonResponse(res, 500, { ok: false, error: "internal server error" });
    });
    return;
  }

  jsonResponse(res, 404, { ok: false, error: "not found" });
});

server.listen(config.port, "127.0.0.1", () => {
  console.log(JSON.stringify({ level: "info", message: "server started", port: config.port }));
});
