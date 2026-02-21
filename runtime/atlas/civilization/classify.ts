/**
 * Multi-signal classifier. Rule-based, deterministic.
 * Output: radar_categories, civ tags, 5D scores, rationale, summary_zh, evidence.
 */

import {
  CIV_FACTIONS,
  FACTION_KEYWORDS,
  FIVE_D_AXES,
  type CivTag,
  type Score5D,
} from "./taxonomy.js";
import {
  RADAR_CATEGORIES,
  RADAR_TAXONOMY,
  getSourcePrior,
  type RadarCategoryId,
} from "../taxonomy/radar_taxonomy.js";

export type NormalizedItem = {
  id?: string;
  source_id?: string;
  title: string;
  source_name?: string;
  summary?: string;
  summary_zh?: string;
  url?: string;
  published_at?: string;
};

export type ClassificationEvidence = {
  matched_keywords?: string[];
  matched_patterns?: string[];
  source_prior_used?: number;
};

export type RadarCategoryScore = {
  id: RadarCategoryId;
  score: number;
  evidence: ClassificationEvidence[];
};

export type CivEnrichedItem = NormalizedItem & {
  radar_categories: RadarCategoryScore[];
  civ_primary_tag: CivTag;
  civ_secondary_tags: CivTag[];
  civ_score: number;
  score_5d: Score5D;
  score_total: number;
  rationale_en: string;
  summary_zh: string;
  summary_zh_reason?: string;
  need_more_evidence?: boolean;
  diagnostics?: {
    category_entropy: number;
    top_gap: number;
    evidence_strength: number;
  };
};

const ZH_SUMMARY_MAP: Partial<Record<CivTag, string>> = {
  "Vinge/Compute": "算力与基础设施",
  "Banks/Governance": "治理与监管",
  Antimemetics: "信息战与认知",
  "TedChiang/Language": "语言与意义",
  Egan: "智能体与数字心智",
  Watts: "意识与自我",
  Simulation: "模拟与虚拟",
  "Religion/Meaning": "意义与伦理",
};

function scoreRadarCategory(
  text: string,
  url: string,
  sourceName: string,
  categoryHint: string,
  categoryId: RadarCategoryId
): { score: number; evidence: ClassificationEvidence[] } {
  const def = RADAR_TAXONOMY[categoryId];
  const t = text.toLowerCase();
  const evidence: ClassificationEvidence[] = [];
  let score = 0;

  const matchedKw: string[] = [];
  for (const kw of def.seed_keywords_en) {
    if (t.includes(kw.toLowerCase())) {
      matchedKw.push(kw);
      score += 0.5;
    }
  }
  for (const kw of def.seed_keywords_zh) {
    if (t.includes(kw) || text.includes(kw)) {
      matchedKw.push(kw);
      score += 0.5;
    }
  }
  if (matchedKw.length > 0) {
    evidence.push({ matched_keywords: matchedKw });
  }

  const matchedPat: string[] = [];
  for (const { pattern, weight } of def.signals) {
    if (pattern.test(text) || pattern.test(url)) {
      matchedPat.push(pattern.source);
      score += weight;
    }
  }
  if (matchedPat.length > 0) {
    evidence.push({ matched_patterns: matchedPat });
  }

  const prior = getSourcePrior(categoryId, sourceName);
  if (prior > 0.3) {
    score += prior * 0.5;
    evidence.push({ source_prior_used: prior });
  }

  if (categoryHint && categoryHint === categoryId) {
    score += 2.2;
    evidence.push({ matched_keywords: [`source_category_hint:${categoryHint}`] });
  }

  return { score: Math.min(5, score), evidence };
}

function scoreAxis(text: string, axis: string): number {
  const t = text.toLowerCase();
  let s = 0;
  if (axis === "compute" && /\b(compute|gpu|training|inference|chip|parameter)\b/.test(t)) s += 2;
  if (axis === "governance" && /\b(regulation|policy|oversight|compliance|antitrust)\b/.test(t)) s += 2;
  if (axis === "narrative" && /\b(story|narrative|meaning|interpret)\b/.test(t)) s += 1;
  if (axis === "behavior" && /\b(agent|autonomous|behavior|persona)\b/.test(t)) s += 2;
  if (axis === "capability" && /\b(capability|ability|skill|performance)\b/.test(t)) s += 1;
  return Math.min(2, s);
}

function generateSummaryZh(tag: CivTag, title: string): string {
  const prefix = ZH_SUMMARY_MAP[tag] ?? tag;
  const t = title.slice(0, 40);
  return `${prefix}：${t}${title.length > 40 ? "…" : ""}`.slice(0, 80);
}

function entropy(counts: number[]): number {
  const total = counts.reduce((a, b) => a + b, 0);
  if (total === 0) return 0;
  let h = 0;
  for (const c of counts) {
    if (c > 0) {
      const p = c / total;
      h -= p * Math.log2(p);
    }
  }
  return h;
}

export function classifyItem(item: NormalizedItem): CivEnrichedItem {
  const text = `${item.title} ${item.summary ?? ""}`;
  const url = item.url ?? "";
  const sourceName = item.source_name ?? "";
  const categoryHint = String((item as { category_hint?: string }).category_hint ?? "");

  const radarScores: RadarCategoryScore[] = RADAR_CATEGORIES.map((id) => {
    const { score, evidence } = scoreRadarCategory(text, url, sourceName, categoryHint, id);
    return { id, score, evidence };
  });
  radarScores.sort((a, b) => b.score - a.score);
  const top2Radar = radarScores.slice(0, 2);

  const textLower = text.toLowerCase();
  const civScores: { tag: CivTag; count: number }[] = [];
  for (const tag of CIV_FACTIONS) {
    const kws = FACTION_KEYWORDS[tag];
    let count = 0;
    for (const kw of kws) {
      if (textLower.includes(kw)) count++;
    }
    if (count > 0) civScores.push({ tag, count });
  }
  civScores.sort((a, b) => b.count - a.count);
  const primary: CivTag = civScores[0]?.tag ?? "Vinge/Compute";
  const secondary: CivTag[] = civScores.slice(1, 3).map((s) => s.tag);

  const score_5d: Score5D = {
    compute: scoreAxis(textLower, "compute"),
    governance: scoreAxis(textLower, "governance"),
    narrative: scoreAxis(textLower, "narrative"),
    behavior: scoreAxis(textLower, "behavior"),
    capability: scoreAxis(textLower, "capability"),
  };
  const civScore = civScores[0]?.count ?? 0;
  const total5d = Object.values(score_5d).reduce((a, b) => a + b, 0);
  const score_total = Math.min(10, total5d + civScore);

  const top1 = top2Radar[0];
  const top2 = top2Radar[1];
  const top1Score = top1?.score ?? 0;
  const top2Score = top2?.score ?? 0;
  const topGap = top1Score - top2Score;
  const top1EvidenceCount = top1?.evidence?.length ?? 0;
  const onlySourcePrior =
    top1?.evidence?.every((e) => e.source_prior_used != null && !e.matched_keywords?.length && !e.matched_patterns?.length) ?? false;
  const needMoreEvidence =
    topGap > 2 && (top1EvidenceCount < 2 || onlySourcePrior);

  const categoryEntropy = entropy(radarScores.map((r) => r.score));
  const evidenceStrength = top1EvidenceCount >= 2 && !onlySourcePrior ? 1 : onlySourcePrior ? 0.2 : 0.5;

  const diagnostics = {
    category_entropy: Math.round(categoryEntropy * 100) / 100,
    top_gap: Math.round(topGap * 100) / 100,
    evidence_strength: evidenceStrength,
  };

  let adjustedRadar = top2Radar;
  if (needMoreEvidence && top1) {
    adjustedRadar = [
      { ...top1, score: Math.max(0, top1.score - 1) },
      ...top2Radar.slice(1),
    ];
  }

  const rationaleParts: string[] = [];
  rationaleParts.push(`Radar: ${top1?.id ?? "—"} (${top1Score})`);
  if (top1?.evidence?.length) {
    const kw = top1.evidence.find((e) => e.matched_keywords?.length);
    if (kw?.matched_keywords?.length) rationaleParts.push(`kw:${kw.matched_keywords.slice(0, 3).join(",")}`);
  }
  rationaleParts.push(`Civ: ${primary} (${civScore})`);
  rationaleParts.push(`5D: ${Object.entries(score_5d).map(([k, v]) => `${k}=${v}`).join(",")}`);
  const rationale_en = rationaleParts.join(". ").slice(0, 240);

  const rawZh = (item.summary_zh ?? "").trim();
  const isPlaceholderOrEmpty = !rawZh || rawZh === "（摘要生成失败）";
  const summary_zh = isPlaceholderOrEmpty ? generateSummaryZh(primary, item.title) : rawZh;
  const summary_zh_reason = isPlaceholderOrEmpty && (item as { summary_zh_reason?: string }).summary_zh_reason
    ? (item as { summary_zh_reason: string }).summary_zh_reason
    : undefined;

  return {
    ...item,
    radar_categories: adjustedRadar,
    civ_primary_tag: primary,
    civ_secondary_tags: secondary,
    civ_score: civScore,
    score_5d,
    score_total,
    rationale_en,
    summary_zh,
    ...(summary_zh_reason && { summary_zh_reason }),
    ...(needMoreEvidence && { need_more_evidence: true }),
    diagnostics,
  };
}

export function classifyItems(items: NormalizedItem[]): CivEnrichedItem[] {
  return items.map(classifyItem);
}
