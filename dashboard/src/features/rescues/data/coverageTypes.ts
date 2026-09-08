/** Domain types behind the Dynamic Rescue Coverage page. */

/** The four coverage levels a rescue escalates through. */
export type CoverageLevel =
  | 'standard'
  | 'expanded'
  | 'extended'
  | 'alternative';

export const COVERAGE_ORDER: CoverageLevel[] = [
  'standard',
  'expanded',
  'extended',
  'alternative',
];

export const COVERAGE_LABEL: Record<CoverageLevel, string> = {
  standard: 'STANDARD',
  expanded: 'EXPANDED',
  extended: 'EXTENDED',
  alternative: 'ALTERNATIVE RECOVERY',
};

/** What a responder is travelling by. */
export type ResponderMode = 'van' | 'bike' | 'foot';

export interface Responder {
  id: string;
  label: string;
  mode: ResponderMode;
  /** "Courier #104 · Van · 4 min away". */
  caption: string;
  x: number;
  y: number;
}

/** A partner plotted on the coverage map. */
export interface CoverageSite {
  id: string;
  label: string;
  x: number;
  y: number;
  /** The rescue this page is about. */
  focus?: boolean;
  /** "(25 boxes)". */
  detail?: string;
}

/** One of the three "why coverage changed" columns. */
export interface CoverageFactor {
  icon: string;
  title: string;
  finding: string;
  metricLabel: string;
  metricValue: string;
}

export interface CoverageEvent {
  time: string;
  title: string;
  detail: string;
}

/** One of the three cards along the bottom. */
export interface CoverageStat {
  label: string;
  value: string;
  icon: string;
}

/** Everything the coverage page renders. */
export interface CoverageData {
  /** "Dispatch Zone Sector 4". */
  zone: string;
  bannerTitle: string;
  bannerBody: string;

  activeRescues: number;
  expandedCount: number;
  reviewRequired: number;

  sites: CoverageSite[];
  responders: Responder[];

  /** Radii of the three coverage rings, in viewBox units. */
  rings: { level: CoverageLevel; radius: number }[];

  trigger: string;
  factors: CoverageFactor[];
  events: CoverageEvent[];

  /** The rescue in focus. */
  partner: string;
  severityLabel: string;
  quantityLine: string;
  handlingNote: string;
  currentState: string;
  minutesRemaining: number;
  pickupWindow: string;

  currentLevel: CoverageLevel;
  levelExplanation: string;

  stats: CoverageStat[];
}
