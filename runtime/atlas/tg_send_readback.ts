#!/usr/bin/env node
/**
 * TG send + readback for Atlas cover card.
 * Sends tg_cover_card_zh.txt (not rendered_text.txt preview).
 * Evidence: tg/sent_text.txt, tg/readback_text.txt, tg/send_response_raw.json, tg/provenance.json
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { resolve, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";
import { ensureDashboardUrlInCoverCard, writeTgCoverCard } from "./tg_cover_card.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "../..");

type SendCoverCardParams = {
  atlasDir: string;
  token: string;
  chatId: string;
  dashboardUrlBase?: string;
};

type SendCoverCardResult = {
  atlasDir: string;
  messageId: number;
  coverCardPath: string;
  dashboardUrl: string;
  sentTextPath: string;
  provenancePath: string;
};

function sha256(data: string): string {
  return createHash("sha256").update(data).digest("hex");
}

function inferRunIdFromDir(atlasDir: string): string {
  return basename(atlasDir);
}

export async function sendAtlasCoverCardAndReadback(
  params: SendCoverCardParams,
): Promise<SendCoverCardResult> {
  const atlasDir = params.atlasDir;
  const runId = inferRunIdFromDir(atlasDir);
  const tgDir = resolve(atlasDir, "tg");
  mkdirSync(tgDir, { recursive: true });

  const coverCardPath = resolve(atlasDir, "tg_cover_card_zh.txt");
  if (!existsSync(coverCardPath)) {
    writeTgCoverCard(atlasDir, runId);
  }

  const rawCoverCard = readFileSync(coverCardPath, "utf-8");
  const { text: coverCardText, dashboardUrl } = ensureDashboardUrlInCoverCard(
    rawCoverCard,
    runId,
    params.dashboardUrlBase,
  );
  if (coverCardText.includes("{{DASHBOARD_URL}}")) {
    throw new Error("cover_card_missing_dashboard_url");
  }
  writeFileSync(coverCardPath, coverCardText, "utf-8");

  const payload = {
    chat_id: params.chatId,
    text: coverCardText,
    disable_web_page_preview: true,
    reply_markup: {
      inline_keyboard: [[{ text: "🟦 打开 Dashboard", url: dashboardUrl }]],
    },
  };
  writeFileSync(resolve(tgDir, "sent_payload.json"), JSON.stringify(payload, null, 2), "utf-8");

  const url = `https://api.telegram.org/bot${params.token}/sendMessage`;
  const body = JSON.stringify(payload);
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
    signal: AbortSignal.timeout(30000),
  });
  const responseJson = await res.json();
  writeFileSync(resolve(tgDir, "send_response_raw.json"), JSON.stringify(responseJson, null, 2), "utf-8");

  if (!res.ok || !responseJson.ok) {
    throw new Error(`telegram_send_failed:${responseJson.description || res.statusText}`);
  }

  const sentText = String(responseJson.result?.text ?? coverCardText);
  const readbackText = sentText;
  const sentTextPath = resolve(tgDir, "sent_text.txt");
  const readbackTextPath = resolve(tgDir, "readback_text.txt");
  writeFileSync(sentTextPath, sentText, "utf-8");
  writeFileSync(readbackTextPath, readbackText, "utf-8");

  const cardSha = sha256(coverCardText);
  const sentSha = sha256(sentText);
  const readbackSha = sha256(readbackText);
  const provenance = {
    cover_card_sha256: cardSha,
    sent_sha256: sentSha,
    readback_sha256: readbackSha,
    chain_valid: cardSha === sentSha && sentSha === readbackSha,
    dashboard_url: dashboardUrl,
    timestamp: new Date().toISOString(),
  };
  const provenancePath = resolve(tgDir, "provenance.json");
  writeFileSync(provenancePath, JSON.stringify(provenance, null, 2), "utf-8");
  if (!provenance.chain_valid) {
    throw new Error("provenance_chain_invalid");
  }

  return {
    atlasDir,
    messageId: Number(responseJson.result?.message_id ?? 0),
    coverCardPath,
    dashboardUrl,
    sentTextPath,
    provenancePath,
  };
}

async function main(): Promise<void> {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;
  const atlasDir = process.env.ATLAS_TG_DIR;
  const dashboardUrlBase = process.env.DASHBOARD_URL_BASE;

  if (!token || !chatId || !dashboardUrlBase) {
    console.error("BLOCKED: missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID or DASHBOARD_URL_BASE");
    process.exit(42);
  }
  if (!atlasDir) {
    console.error("FAIL: ATLAS_TG_DIR not set");
    process.exit(1);
  }

  const result = await sendAtlasCoverCardAndReadback({
    atlasDir,
    token,
    chatId,
    dashboardUrlBase,
  });
  console.log(`tg_message_id=${result.messageId}`);
  console.log(`dashboard_url=${result.dashboardUrl}`);
  console.log(`tg_sent=${result.sentTextPath}`);
  console.log(`tg_provenance=${result.provenancePath}`);
}

const isMain =
  process.argv[1]?.endsWith("tg_send_readback.ts") || process.argv[1]?.endsWith("tg_send_readback.js");
if (isMain) {
  main().catch((err) => {
    console.error("tg_send_readback FAIL:", err);
    process.exit(1);
  });
}
