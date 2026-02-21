#!/usr/bin/env node
/**
 * Deterministic TG natural-language router for Atlas.
 * P0: rule-based only, no LLM dependency.
 */

export type AtlasNlIntent = "atlas_run" | "help";

export type AtlasNlRouteResult = {
  intent: AtlasNlIntent;
  matched: string[];
  normalizedText: string;
};

const DIRECT_TRIGGERS = [
  "今天的文明态势雷达",
  "给我最新AI时政雷达",
  "生成一份文明态势看板并发TG",
  "打开dashboard",
] as const;

const RUN_KEYWORDS = [
  "文明态势雷达",
  "ai时政雷达",
  "文明态势看板",
  "打开dashboard",
  "打开 dashboard",
  "open dashboard",
  "atlas",
] as const;

function normalizeText(input: string): string {
  return input.trim().toLowerCase().replace(/\s+/g, " ");
}

function compactText(input: string): string {
  return normalizeText(input).replace(/[，。！？、；：“”"'`~!@#$%^&*()_+\-=[\]{}|\\:;<>,.?/]/g, "");
}

function isSlashRunCommand(text: string): boolean {
  const t = normalizeText(text);
  if (t === "/atlas" || t === "/atlas run") return true;
  if (/^\/atlas\s+run(\s+.*)?$/.test(t)) return true;
  // /radar schedule -> legacy, do NOT route to atlas_run (Radar 已停用)
  return false;
}

export function routeAtlasIntent(input: string): AtlasNlRouteResult {
  const normalized = normalizeText(input);
  const compact = compactText(input);

  if (!normalized) {
    return { intent: "help", matched: [], normalizedText: normalized };
  }

  if (isSlashRunCommand(normalized)) {
    return { intent: "atlas_run", matched: ["/atlas run"], normalizedText: normalized };
  }

  const matched = new Set<string>();
  for (const trigger of DIRECT_TRIGGERS) {
    if (normalized.includes(trigger.toLowerCase()) || compact.includes(compactText(trigger))) {
      matched.add(trigger);
    }
  }
  for (const kw of RUN_KEYWORDS) {
    if (normalized.includes(kw) || compact.includes(compactText(kw))) {
      matched.add(kw);
    }
  }

  if (matched.size > 0) {
    return {
      intent: "atlas_run",
      matched: Array.from(matched).sort(),
      normalizedText: normalized,
    };
  }

  return {
    intent: "help",
    matched: [],
    normalizedText: normalized,
  };
}

function parseCliText(): string {
  const args = process.argv.slice(2);
  const fromFlag = args.find((a) => a.startsWith("--text="));
  if (fromFlag) {
    return fromFlag.slice("--text=".length);
  }
  const textIdx = args.indexOf("--text");
  if (textIdx >= 0 && args[textIdx + 1]) {
    return args[textIdx + 1];
  }
  return process.env.ATLAS_NL_TEXT ?? "";
}

const isMain = process.argv[1]?.endsWith("tg_nl_router.ts") || process.argv[1]?.endsWith("tg_nl_router.js");
if (isMain) {
  const input = parseCliText();
  const result = routeAtlasIntent(input);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}
