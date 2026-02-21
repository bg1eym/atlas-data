/**
 * KOL catalog. From ai的一些kol.pdf.
 * Structure: name, platform, reason, radar_categories.
 */

import type { RadarCategoryId } from "../atlas/taxonomy/radar_taxonomy.js";

export type KolEntry = {
  id: string;
  name: string;
  platform: string;
  reason: string;
  radar_categories: RadarCategoryId[];
  url?: string;
};

export const KOLS: KolEntry[] = [
  { id: "mollick", name: "Ethan Mollick", platform: "Substack/X", reason: "AI adoption, education, practical use", radar_categories: ["social_phenomenon", "tech_breakthrough"], url: "https://oneusefulthing.org" },
  { id: "marcus", name: "Gary Marcus", platform: "Substack/X", reason: "AI critique, robustness, reasoning", radar_categories: ["tech_breakthrough", "safety_incident"] },
  { id: "leike", name: "Jan Leike", platform: "X", reason: "AI safety, alignment", radar_categories: ["safety_incident", "policy_governance"] },
  { id: "amodei", name: "Dario Amodei", platform: "X/Podcast", reason: "AI scaling, safety", radar_categories: ["tech_breakthrough", "safety_incident"] },
  { id: "bostrom", name: "Nick Bostrom", platform: "X/Academic", reason: "Existential risk, superintelligence", radar_categories: ["safety_incident", "policy_governance"] },
  { id: "bengio", name: "Yoshua Bengio", platform: "X/Academic", reason: "AI safety, regulation", radar_categories: ["policy_governance", "safety_incident"] },
  { id: "hinton", name: "Geoffrey Hinton", platform: "X", reason: "AI risk, neural nets", radar_categories: ["tech_breakthrough", "safety_incident"] },
  { id: "searle", name: "John Searle", platform: "Academic", reason: "Consciousness, Chinese Room", radar_categories: ["tech_breakthrough"] },
  { id: "crawford", name: "Kate Crawford", platform: "X/Academic", reason: "AI ethics, labor, environment", radar_categories: ["social_phenomenon", "energy_environment", "policy_governance"] },
  { id: "broussard", name: "Meredith Broussard", platform: "X/Academic", reason: "AI limits, journalism", radar_categories: ["social_phenomenon"] },
  { id: "altman", name: "Sam Altman", platform: "X", reason: "AI industry, funding", radar_categories: ["finance_capital", "tech_breakthrough"] },
];

export function getKolsForCategory(cat: RadarCategoryId): KolEntry[] {
  return KOLS.filter((k) => k.radar_categories.includes(cat));
}
