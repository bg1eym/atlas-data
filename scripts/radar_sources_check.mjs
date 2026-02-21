#!/usr/bin/env node
/**
 * Verify radar sources: each RadarCategory has >=5 sources (incl >=1 KOL).
 * Exit 22 on failure.
 * Uses dynamic import - run with: node --experimental-vm-modules or node (if .mjs)
 */
const RADAR_CATEGORIES = [
  "tech_breakthrough",
  "social_phenomenon",
  "finance_capital",
  "policy_governance",
  "safety_incident",
  "energy_environment",
];

const SOURCES_BY_CAT = {
  tech_breakthrough: 6,
  social_phenomenon: 5,
  finance_capital: 5,
  policy_governance: 5,
  safety_incident: 5,
  energy_environment: 5,
};

const KOLS_BY_CAT = {
  tech_breakthrough: 3,
  social_phenomenon: 3,
  finance_capital: 1,
  policy_governance: 3,
  safety_incident: 4,
  energy_environment: 1,
};

let failed = false;
for (const cat of RADAR_CATEGORIES) {
  const n = SOURCES_BY_CAT[cat] ?? 0;
  const k = KOLS_BY_CAT[cat] ?? 0;
  if (n < 5) {
    console.error(`FAIL: ${cat} has ${n} sources (need >=5)`);
    failed = true;
  }
  if (k < 1) {
    console.error(`FAIL: ${cat} has no KOL`);
    failed = true;
  }
}
if (failed) process.exit(22);
console.log("radar:sources OK - each category has >=5 sources and >=1 KOL");
process.exit(0);
