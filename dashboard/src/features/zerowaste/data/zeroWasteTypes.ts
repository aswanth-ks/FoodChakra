/**
 * Domain types behind the Zero-Waste Network console.
 *
 * This is the fallback tier. A rescue reaches it only after the human tier has
 * failed: nobody accepted the surplus in time, or it is no longer fit for
 * people. The tier's job is to keep that surplus out of landfill by routing it
 * down the recovery hierarchy instead.
 *
 * The hierarchy is ordered, and the order is not cosmetic - it is the food-use
 * hierarchy that waste regulation is written around. Routing must always try
 * the highest recoverable tier first.
 */

/** One rung of the food-use hierarchy, best first. */
export type RecoveryTier =
  | 'human'
  | 'animal_feed'
  | 'composting'
  | 'energy'
  | 'landfill';

export const TIER_LABEL: Record<RecoveryTier, string> = {
  human: 'Human Consumption',
  animal_feed: 'Animal Feed',
  composting: 'Composting',
  energy: 'Energy Recovery',
  landfill: 'Landfill',
};

/** Short form for chips and table cells. */
export const TIER_SHORT: Record<RecoveryTier, string> = {
  human: 'Human',
  animal_feed: 'Feed',
  composting: 'Compost',
  energy: 'Energy',
  landfill: 'Landfill',
};

/** Ordered best-to-worst. Routing walks this in order. */
export const TIER_ORDER: RecoveryTier[] = [
  'human',
  'animal_feed',
  'composting',
  'energy',
  'landfill',
];

/* ------------------------------------------------------------- overview */

/** Volume recovered at one rung of the hierarchy. */
export interface TierVolume {
  tier: RecoveryTier;
  /** Kilograms in the reporting window. */
  kg: number;
  /** Share of total volume, 0-100. */
  share: number;
  /** How many consignments made up that volume. */
  consignments: number;
}

/** One open case waiting on a routing decision. */
export interface FallbackCase {
  id: string;
  /** The rescue this fell out of. */
  rescueId: string;
  surplus: string;
  /** Kilograms. */
  kg: number;
  partner: string;
  zone: string;
  /** Why the human tier failed. */
  reason: string;
  /** Minutes until the surplus is no longer recoverable at its best tier. */
  minutesLeft: number;
  /** The tier routing currently proposes. */
  proposedTier: RecoveryTier;
  severity: 'critical' | 'attention' | 'steady';
}

/** One entry in the diversion feed. */
export interface DiversionEvent {
  when: string;
  title: string;
  detail: string;
  tier: RecoveryTier;
  kg: number;
}

export interface ZeroWasteOverview {
  window: string;
  totals: {
    /** Kilograms diverted from landfill in the window. */
    divertedKg: number;
    /** Share of fallback volume kept out of landfill, 0-100. */
    diversionRate: number;
    openCases: number;
    activePartners: number;
    /** Kilograms that still reached landfill. */
    landfillKg: number;
    /** Tonnes of CO2e avoided, as shown. */
    co2Avoided: string;
  };
  hierarchy: TierVolume[];
  cases: FallbackCase[];
  events: DiversionEvent[];
}

/* --------------------------------------------------------------------------
   Fallback Opportunity has its own vocabulary - recovery *pathways* rather
   than tiers - and lives in `fallbackTypes.ts`, following the Stitch design
   for that screen.
   -------------------------------------------------------------------------- */

/* ------------------------------------------------------ recovery partners */

export type RecoveryPartnerStatus = 'accepting' | 'at_capacity' | 'offline';

export const RECOVERY_STATUS_LABEL: Record<RecoveryPartnerStatus, string> = {
  accepting: 'Accepting',
  at_capacity: 'At Capacity',
  offline: 'Offline',
};

export interface RecoveryPartnerRow {
  id: string;
  name: string;
  initials: string;
  tier: RecoveryTier;
  zone: string;
  status: RecoveryPartnerStatus;
  /** Daily intake ceiling, kilograms. */
  capacityKg: number;
  /** Taken today, kilograms. */
  usedKg: number;
  /** Categories the partner will accept. */
  accepts: string[];
  /** "Open 06:00-18:00". */
  hours: string;
  /** Kilograms taken in the trailing 30 days. */
  lifetimeKg: number;
}

export interface RecoveryPartnerDetail {
  id: string;
  /** Licence or permit reference, as shown. */
  licence: string;
  contact: string;
  /** Turnaround from collection to processing. */
  turnaround: string;
  /** What the partner will not take. */
  excludes: string[];
  /** Free-text standing note. */
  note: string;
  activity: { when: string; title: string; detail: string; kg: number }[];
}

export interface RecoveryPartnerDirectory {
  totals: {
    all: number;
    accepting: number;
    atCapacity: number;
    offline: number;
  };
  zones: string[];
  rows: RecoveryPartnerRow[];
  details: Record<string, RecoveryPartnerDetail>;
}

/* -------------------------------------------------------------- routing */

/** One ordered routing rule. */
export interface RoutingRule {
  id: string;
  /** Evaluation order; lower runs first. */
  priority: number;
  name: string;
  /** Plain-language match condition. */
  condition: string;
  /** Where a match is sent. */
  destination: RecoveryTier;
  /** Whether the rule is currently evaluated. */
  enabled: boolean;
  /** Matches in the reporting window. */
  matches: number;
  /** Why the rule exists. */
  rationale: string;
}

/** One consignment currently being routed. */
export interface RoutingPreviewRow {
  caseId: string;
  surplus: string;
  kg: number;
  category: string;
  /** The rule that claimed it. */
  ruleId: string;
  destination: RecoveryTier;
  partner: string;
  /** Whether routing could place it at all. */
  placed: boolean;
}

export interface RoutingPolicy {
  window: string;
  /** Consignments routed automatically in the window, 0-100. */
  autoRoutedShare: number;
  /** Consignments that needed an operator, in the window. */
  manualCount: number;
  /** Consignments no rule could place. */
  unplacedCount: number;
  rules: RoutingRule[];
  preview: RoutingPreviewRow[];
}

/* --------------------------------------------------------------- shared */

/** "1h 10m left" / "25m left" - mirrors the rescue module's formatter. */
export function formatRemaining(minutes: number): string {
  if (minutes <= 0) return 'Window closed';
  if (minutes >= 60) {
    const hours = Math.floor(minutes / 60);
    const rest = minutes % 60;
    return rest === 0 ? `${hours}h left` : `${hours}h ${rest}m left`;
  }
  return `${minutes}m left`;
}
