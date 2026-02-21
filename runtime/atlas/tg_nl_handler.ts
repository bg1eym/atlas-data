#!/usr/bin/env node
/**
 * TG NL handler:
 * - Slash command keeps compatibility.
 * - Natural language uses deterministic router.
 * - atlas_run intent invokes Atlas pipeline and delivers cover card.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { routeAtlasIntent } from "./tg_nl_router.js";
import { runAtlasPipeline } from "./run_atlas.js";
import { sendAtlasCoverCardAndReadback } from "./tg_send_readback.js";

type HandlerResult =
  | {
      kind: "atlas_run";
      runId: string;
      outDir: string;
      dashboardUrl: string;
      messageId: number;
    }
  | {
      kind: "help";
      helpText: string;
      messageId?: number;
    };

const NOT_CONFIGURED_INSTRUCTIONS = `
NOT_CONFIGURED: missing TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID / DASHBOARD_URL_BASE

Configure in OpenClaw TG skill env or service env injection.
See README_TG.md for exact config locations.

Example:
  export TELEGRAM_BOT_TOKEN="123456:your_token"
  export TELEGRAM_CHAT_ID="-100xxxxxxxxxx"
  export DASHBOARD_URL_BASE="http://localhost:5173/?run_id={{run_id}}"
`.trim();

function getRequiredEnv(): { token: string; chatId: string; dashboardUrlBase: string } {
  const token = process.env.TELEGRAM_BOT_TOKEN?.trim();
  const chatId = process.env.TELEGRAM_CHAT_ID?.trim();
  const dashboardUrlBase = process.env.DASHBOARD_URL_BASE?.trim();
  const missing: string[] = [];
  if (!token) missing.push("TELEGRAM_BOT_TOKEN");
  if (!chatId) missing.push("TELEGRAM_CHAT_ID");
  if (!dashboardUrlBase) missing.push("DASHBOARD_URL_BASE");
  if (missing.length > 0) {
    const reason = `missing ${missing.join(", ")}`;
    console.error(`delivery_verdict=NOT_CONFIGURED`);
    console.error(`delivery_reason=${reason}`);
    console.error(NOT_CONFIGURED_INSTRUCTIONS);
    const blockedDir = resolve(process.cwd(), "out/atlas", `blocked-nl-${Date.now()}`);
    mkdirSync(blockedDir, { recursive: true });
    mkdirSync(resolve(blockedDir, "audit"), { recursive: true });
    writeFileSync(
      resolve(blockedDir, "audit/summary.json"),
      JSON.stringify(
        {
          pipeline_verdict: "OK",
          delivery_verdict: "NOT_CONFIGURED",
          delivery_reason: reason,
          steps: ["Configure TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, DASHBOARD_URL_BASE", "See README_TG.md"],
          exit_code: 42,
          finished_at: new Date().toISOString(),
        },
        null,
        2
      ),
      "utf-8"
    );
    process.exit(42);
  }
  return { token, chatId, dashboardUrlBase };
}

function buildHelpText(): string {
  return [
    "我能帮你运行 Atlas 文明态势雷达。",
    "",
    "可直接发送：",
    "1) 今天的文明态势雷达",
    "2) 给我最新AI时政雷达",
    "3) 生成一份文明态势看板并发TG",
    "4) 打开dashboard",
  ].join("\n");
}

async function sendPlainHelp(token: string, chatId: string, text: string): Promise<number> {
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text,
      disable_web_page_preview: true,
    }),
    signal: AbortSignal.timeout(30000),
  });
  const data = await res.json();
  if (!res.ok || !data.ok) {
    throw new Error(`telegram_help_send_failed:${data.description || res.statusText}`);
  }
  return Number(data.result?.message_id ?? 0);
}

export async function handleAtlasTelegramText(inputText: string): Promise<HandlerResult> {
  const { token, chatId, dashboardUrlBase } = getRequiredEnv();
  const route = routeAtlasIntent(inputText);

  if (route.intent !== "atlas_run") {
    let helpText = buildHelpText();
    if (/\/radar\b/i.test(inputText)) {
      helpText = "Radar 已停用。请使用 Atlas 命令。\n\n" + helpText;
    }
    const messageId = await sendPlainHelp(token, chatId, helpText);
    return { kind: "help", helpText, messageId };
  }

  const run = await runAtlasPipeline();
  const sent = await sendAtlasCoverCardAndReadback({
    atlasDir: run.outDir,
    token,
    chatId,
    dashboardUrlBase,
  });

  // Update audit summary: delivery_verdict=OK after successful TG send
  const auditPath = resolve(run.outDir, "audit/summary.json");
  if (existsSync(auditPath)) {
    try {
      const audit = JSON.parse(readFileSync(auditPath, "utf-8")) as Record<string, unknown>;
      audit.delivery_verdict = "OK";
      audit.delivery_reason = null;
      audit.finished_at = new Date().toISOString();
      writeFileSync(auditPath, JSON.stringify(audit, null, 2), "utf-8");
    } catch {}
  }

  return {
    kind: "atlas_run",
    runId: run.runId,
    outDir: run.outDir,
    dashboardUrl: sent.dashboardUrl,
    messageId: sent.messageId,
  };
}

function parseInputText(): string {
  const args = process.argv.slice(2);
  const fromFlag = args.find((a) => a.startsWith("--text="));
  if (fromFlag) {
    return fromFlag.slice("--text=".length);
  }
  const idx = args.indexOf("--text");
  if (idx >= 0 && args[idx + 1]) {
    return args[idx + 1];
  }
  return process.env.ATLAS_NL_TEXT?.trim() || "";
}

async function main(): Promise<void> {
  const inputText = parseInputText();
  if (!inputText) {
    console.error("FAIL: empty NL input");
    process.exit(1);
  }
  const result = await handleAtlasTelegramText(inputText);
  if (result.kind === "atlas_run") {
    console.log(`intent=atlas_run`);
    console.log(`run_id=${result.runId}`);
    console.log(`out_dir=${result.outDir}`);
    console.log(`dashboard_url=${result.dashboardUrl}`);
    console.log(`reply_message_id=${result.messageId}`);
    return;
  }
  console.log("intent=help");
  console.log(`reply_message_id=${result.messageId ?? 0}`);
}

const isMain =
  process.argv[1]?.endsWith("tg_nl_handler.ts") || process.argv[1]?.endsWith("tg_nl_handler.js");
if (isMain) {
  main().catch((err) => {
    console.error("tg_nl_handler FAIL:", err);
    process.exit(1);
  });
}
