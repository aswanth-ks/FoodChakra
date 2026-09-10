/**
 * Domain types behind the Fallback Opportunity screen.
 *
 * These follow the Stitch design (`a75b3478a61043db95d66ff928a1c838`) rather
 * than the tier vocabulary the rest of the Zero-Waste module uses: the design
 * speaks in **recovery pathways** an operator picks between, not rungs of a
 * hierarchy. The two describe the same thing from different angles - a pathway
 * carries the tier it lands on, so the overview and this screen stay
 * reconcilable - but the screen's own language is the design's.
 */

import type { RecoveryTier } from './zeroWasteTypes';

/** How available a pathway is, as the design's status pills put it. */
export type PathwayState = 'recommended' | 'available' | 'limited' | 'check';

export const PATHWAY_STATE_LABEL: Record<PathwayState, string> = {
  recommended: 'Recommended',
  available: 'Available',
  limited: 'Limited',
  check: 'Check',
};

/** One selectable diversion stream. */
export interface RecoveryPathway {
  id: string;
  /** Material symbol name, as the design specifies. */
  icon: string;
  name: string;
  state: PathwayState;
  /** The design's own status word, which is not always the state label
   *  ("1 Partner" rather than "Limited"). */
  statusLabel: string;
  detail: string;
  /** Which rung of the recovery hierarchy this pathway lands on. */
  tier: RecoveryTier;
}

/** One partner that can fulfil the selected pathway. */
export interface PathwayPartner {
  id: string;
  /** Single-letter avatar mark, as the design draws it. */
  mark: string;
  name: string;
  kind: string;
  pathwayId: string;
  etaMinutes: number;
  available: boolean;
  /** Destination sub-label on the routing strip. */
  destinationKind: string;
}

/** The chain-of-custody strip. */
export interface RoutingPlan {
  originName: string;
  originDetail: string;
  action: string;
  pickupWindow: string;
  partnerStatus: string;
  handoverRequirement: string;
}

/** One entry in the fallback activity trail. */
export interface FallbackActivityEntry {
  time: string;
  title: string;
  /** Completed steps take the tick; earlier context takes the dot. */
  done: boolean;
}

/** Everything the Fallback Opportunity screen renders. */
export interface FallbackOpportunity {
  id: string;
  originRescueId: string;
  /** Banner tags, in the design's order. */
  tags: string[];
  partner: string;
  surplusSummary: string;
  issue: string;
  minutesRemaining: number;

  inventory: {
    state: string;
    category: string;
    categoryDetail: string;
    window: string;
    windowDetail: string;
    handlingNote: string;
  };

  pathways: RecoveryPathway[];
  /** The pathway the matcher recommends. */
  recommendedPathwayId: string;
  recommendationStatus: string;
  recommendationAnalysis: string;

  partners: PathwayPartner[];
  routing: RoutingPlan;
  activity: FallbackActivityEntry[];
}
