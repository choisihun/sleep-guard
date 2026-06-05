#!/usr/bin/env node

const https = require("node:https");

const token = process.env.TELEGRAM_BOT_TOKEN;
if (!token) {
  console.error("TELEGRAM_BOT_TOKEN is required");
  process.exit(1);
}

https
  .get(`https://api.telegram.org/bot${token}/getUpdates`, (res) => {
    const chunks = [];
    res.on("data", (chunk) => chunks.push(chunk));
    res.on("end", () => {
      const body = Buffer.concat(chunks).toString("utf8");
      if (res.statusCode < 200 || res.statusCode >= 300) {
        console.error(body);
        process.exit(1);
      }

      const payload = JSON.parse(body);
      const chats = new Map();
      for (const update of payload.result || []) {
        const message = update.message || update.channel_post;
        if (!message?.chat?.id) {
          continue;
        }
        chats.set(message.chat.id, {
          id: message.chat.id,
          type: message.chat.type,
          title: message.chat.title || [message.chat.first_name, message.chat.last_name].filter(Boolean).join(" "),
          username: message.chat.username || "",
        });
      }

      if (chats.size === 0) {
        console.log("No chats found. Send /start to the bot, then run this again.");
        return;
      }

      console.log(JSON.stringify([...chats.values()], null, 2));
    });
  })
  .on("error", (error) => {
    console.error(error.message);
    process.exit(1);
  });
