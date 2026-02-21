/**
 * AI relevance filter. Hard rules: denylist keywords => reject.
 * Copied from radar. AI-only: denylist hits rejected.
 */

export type RadarItem = {
  title: string;
  source: string;
  summary: string;
  url: string;
  category?: string;
};

export type AiFilterReport = {
  keywords_hit: string[];
  rejected_items_count: number;
  rejected_samples: Array<{ title: string; source: string; reason: string }>;
};

const DENYLIST_RE = new RegExp(
  [
    "Gaza",
    "Hostage",
    "Palestinian",
    "Israel",
    "北加沙",
    "人质",
    "巴勒斯坦",
    "房地产",
    "real-estate",
    "property developer",
    "hostage",
    "palestinians",
  ].join("|"),
  "i"
);

export function filterAiRelevance(items: RadarItem[]): {
  allowed: RadarItem[];
  rejected: RadarItem[];
  report: AiFilterReport;
} {
  const allowed: RadarItem[] = [];
  const rejected: RadarItem[] = [];
  const keywordsHit: string[] = [];
  const rejectedSamples: AiFilterReport["rejected_samples"] = [];

  for (const item of items) {
    const text = `${item.title} ${item.summary}`;
    const m = text.match(DENYLIST_RE);
    if (m) {
      const kw = m[0];
      if (!keywordsHit.includes(kw)) {
        keywordsHit.push(kw);
      }
      rejected.push(item);
      if (rejectedSamples.length < 3) {
        rejectedSamples.push({
          title: item.title,
          source: item.source,
          reason: `denylist: ${kw}`,
        });
      }
    } else {
      allowed.push(item);
    }
  }

  return {
    allowed,
    rejected,
    report: {
      keywords_hit: keywordsHit,
      rejected_items_count: rejected.length,
      rejected_samples: rejectedSamples,
    },
  };
}
