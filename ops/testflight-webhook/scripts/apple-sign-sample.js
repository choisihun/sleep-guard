#!/usr/bin/env node

const crypto = require("node:crypto");

const secret = process.env.APPLE_WEBHOOK_SECRET;
if (!secret) {
  console.error("APPLE_WEBHOOK_SECRET is required");
  process.exit(1);
}

let body = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  body += chunk;
});
process.stdin.on("end", () => {
  const digest = crypto.createHmac("sha256", secret).update(body).digest("hex");
  process.stdout.write(`hmacsha256=${digest}`);
});
