/**
 * Radar taxonomy: 6+ categories from ai时政雷达.pdf structure.
 * Keywords/signals extracted and machine-ruleable.
 */

export const RADAR_CATEGORIES = [
  "tech_breakthrough",
  "social_phenomenon",
  "finance_capital",
  "policy_governance",
  "safety_incident",
  "energy_environment",
] as const;

export type RadarCategoryId = (typeof RADAR_CATEGORIES)[number];

export type RadarCategoryDef = {
  id: RadarCategoryId;
  label_en: string;
  label_zh: string;
  seed_keywords_en: string[];
  seed_keywords_zh: string[];
  signals: Array<{ pattern: RegExp; weight: number }>;
  source_prior: Record<string, number>;
};

/** Source prior: higher = more likely to belong to this category. 0–1 scale. */
const DEFAULT_SOURCE_PRIOR = 0.3;

export const RADAR_TAXONOMY: Record<RadarCategoryId, RadarCategoryDef> = {
  tech_breakthrough: {
    id: "tech_breakthrough",
    label_en: "Tech Breakthrough",
    label_zh: "技术突破",
    seed_keywords_en: [
      "breakthrough",
      "benchmark",
      "SOTA",
      "state of the art",
      "model release",
      "GPT",
      "Claude",
      "Gemini",
      "training",
      "inference",
      "parameter",
      "scaling",
      "multimodal",
      "agent",
      "reasoning",
    ],
    seed_keywords_zh: ["突破", "基准", "发布", "模型", "训练", "推理", "参数", "多模态", "智能体"],
    signals: [
      { pattern: /\b(GPT-|Claude|Gemini|Llama|Mistral)\b/i, weight: 2 },
      { pattern: /\b(SOTA|state of the art|benchmark)\b/i, weight: 2 },
      { pattern: /\b(release|launch|announce)\b.*\b(model|API)\b/i, weight: 1.5 },
    ],
    source_prior: {
      "OpenAI Blog": 0.7,
      "Anthropic News": 0.7,
      "DeepMind Blog": 0.7,
      "OpenAI GitHub Releases": 0.8,
    },
  },
  social_phenomenon: {
    id: "social_phenomenon",
    label_en: "Social Phenomenon",
    label_zh: "社会现象",
    seed_keywords_en: [
      "adoption",
      "usage",
      "workforce",
      "job",
      "education",
      "consumer",
      "viral",
      "trend",
      "impact",
      "society",
      "public",
      "perception",
    ],
    seed_keywords_zh: ["采用", "就业", "教育", "消费者", "社会影响", "公众"],
    signals: [
      { pattern: /\b(workforce|job|employment|layoff)\b/i, weight: 2 },
      { pattern: /\b(adoption|usage|consumer|viral)\b/i, weight: 1.5 },
      { pattern: /\b(education|student|school)\b.*\b(AI|AI)\b/i, weight: 1.5 },
    ],
    source_prior: {},
  },
  finance_capital: {
    id: "finance_capital",
    label_en: "Finance & Capital",
    label_zh: "金融与资本",
    seed_keywords_en: [
      "funding",
      "investment",
      "valuation",
      "IPO",
      "venture",
      "capital",
      "revenue",
      "profit",
      "market",
      "stock",
      "acquisition",
      "merger",
    ],
    seed_keywords_zh: ["融资", "投资", "估值", "上市", "收购", "并购", "市场"],
    signals: [
      { pattern: /\b(funding|investment|valuation|IPO|venture)\b/i, weight: 2 },
      { pattern: /\b(acquisition|merger|acquire)\b/i, weight: 2 },
      { pattern: /\b(revenue|profit|market cap)\b/i, weight: 1 },
    ],
    source_prior: {},
  },
  policy_governance: {
    id: "policy_governance",
    label_en: "Policy & Governance",
    label_zh: "政策与治理",
    seed_keywords_en: [
      "regulation",
      "policy",
      "AI Act",
      "legislation",
      "oversight",
      "compliance",
      "antitrust",
      "government",
      "agency",
      "standard",
      "law",
      "enforcement",
    ],
    seed_keywords_zh: ["监管", "政策", "立法", "合规", "反垄断", "政府"],
    signals: [
      { pattern: /\b(AI Act|EU AI|enforcement)\b/i, weight: 2 },
      { pattern: /\b(regulation|legislation|oversight|compliance)\b/i, weight: 2 },
      { pattern: /\b(antitrust|FTC|DOJ|EU)\b/i, weight: 1.5 },
    ],
    source_prior: {},
  },
  safety_incident: {
    id: "safety_incident",
    label_en: "Safety & Incident",
    label_zh: "安全事故",
    seed_keywords_en: [
      "safety",
      "incident",
      "breach",
      "attack",
      "vulnerability",
      "exploit",
      "misuse",
      "harm",
      "risk",
      "alignment",
      "jailbreak",
    ],
    seed_keywords_zh: ["安全", "事故", "漏洞", "攻击", "滥用", "风险", "对齐"],
    signals: [
      { pattern: /\b(breach|attack|vulnerability|exploit)\b/i, weight: 2 },
      { pattern: /\b(safety|alignment|jailbreak|misuse)\b/i, weight: 1.5 },
      { pattern: /\b(incident|harm|risk)\b/i, weight: 1 },
    ],
    source_prior: {},
  },
  energy_environment: {
    id: "energy_environment",
    label_en: "Energy & Environment",
    label_zh: "能源/环境",
    seed_keywords_en: [
      "energy",
      "power",
      "carbon",
      "emission",
      "datacenter",
      "cooling",
      "sustainability",
      "climate",
      "water",
      "electricity",
    ],
    seed_keywords_zh: ["能源", "电力", "碳", "排放", "数据中心", "可持续"],
    signals: [
      { pattern: /\b(datacenter|data center|power consumption)\b/i, weight: 2 },
      { pattern: /\b(carbon|emission|sustainability|climate)\b/i, weight: 2 },
      { pattern: /\b(energy|electricity|cooling)\b.*\b(AI|AI)\b/i, weight: 1.5 },
    ],
    source_prior: {},
  },
};

export function getSourcePrior(categoryId: RadarCategoryId, sourceName: string): number {
  const def = RADAR_TAXONOMY[categoryId];
  const prior = def.source_prior[sourceName];
  return prior ?? DEFAULT_SOURCE_PRIOR;
}
