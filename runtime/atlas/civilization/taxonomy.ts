/**
 * Civilization taxonomy: 8 factions + 5D axes.
 * Deterministic, rule-based. No external calls.
 */

export const CIV_FACTIONS = [
  "Vinge/Compute",
  "Banks/Governance",
  "Antimemetics",
  "TedChiang/Language",
  "Egan",
  "Watts",
  "Simulation",
  "Religion/Meaning",
] as const;

export type CivTag = (typeof CIV_FACTIONS)[number];

export const FIVE_D_AXES = [
  "compute",
  "governance",
  "narrative",
  "behavior",
  "capability",
] as const;

export type FiveDAxis = (typeof FIVE_D_AXES)[number];

export type Score5D = Record<FiveDAxis, number>;

/** Keyword patterns per faction (lowercase). Match in title+summary. */
export const FACTION_KEYWORDS: Record<CivTag, string[]> = {
  "Vinge/Compute": [
    "compute",
    "gpu",
    "datacenter",
    "scaling",
    "inference cost",
    "chip export",
    "hardware",
    "training",
    "model size",
    "parameters",
  ],
  "Banks/Governance": [
    "regulation",
    "policy",
    "antitrust",
    "agency",
    "oversight",
    "standards",
    "compliance",
    "legislation",
    "government",
  ],
  Antimemetics: [
    "misinformation",
    "deepfake",
    "propaganda",
    "cognitive",
    "memetic",
    "influence ops",
    "disinformation",
    "manipulation",
  ],
  "TedChiang/Language": [
    "prompt",
    "language",
    "meaning",
    "interpretability",
    "communication",
    "translation",
    "nlp",
    "llm",
  ],
  Egan: [
    "agent",
    "persona",
    "copy",
    "replica",
    "digital mind",
    "autonomous",
    "agi",
  ],
  Watts: [
    "consciousness",
    "self",
    "illusion",
    "sentience",
    "awareness",
    "blindsight",
  ],
  Simulation: [
    "world model",
    "simulator",
    "synthetic",
    "virtual",
    "simulation",
    "digital twin",
  ],
  "Religion/Meaning": [
    "spiritual",
    "religion",
    "purpose",
    "existential",
    "meaning",
    "ethics",
    "moral",
  ],
};
