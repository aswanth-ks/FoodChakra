/** Domain types behind the Performance & Logistics Analytics page. */

/** A headline metric with its period-on-period movement. */
export interface AnalyticsMetric {
  label: string;
  icon: string;
  value: string;
  /** "+2.1%" / "-1.8 min". */
  delta: string;
  /** Whether the delta is an improvement — not whether it points up. A
   *  falling matching time is good, so direction and sentiment differ. */
  improved: boolean;
  /** Which arrow to draw. */
  direction: 'up' | 'down';
  caption: string;
}

/** One day in the performance chart. */
export interface DailyVolume {
  completed: number;
  unresolved: number;
}

/** One step of the conversion funnel. */
export interface FunnelStage {
  step: string;
  title: string;
  count: string;
  caption: string;
  /** 0-100, the share of the original volume still present. */
  percent: number;
  /** "95.9% to dispatch". Absent on the final stage. */
  handoff?: string;
}

/** A labelled proportion with its own explanation. */
export interface RateRow {
  label: string;
  percent: number;
  caption: string;
  /** Green when the number is a success measure rather than a failure one. */
  positive?: boolean;
}

/** One of the four intervention counters. */
export interface InterventionStat {
  label: string;
  value: string;
  caption: string;
  tone?: 'critical';
}

/** A ranked friction point. */
export interface Bottleneck {
  rank: number;
  title: string;
  caption: string;
  percent: number;
}

/** One row of the sector table. */
export interface SectorRow {
  area: string;
  rescues: number;
  successRate: string;
  avgMatch: string;
  status: 'Healthy' | 'Monitor' | 'Needs attention';
}

/** Everything the Analytics page renders. */
export interface AnalyticsData {
  contextLabel: string;
  reportingWindow: string;
  scopes: string[];
  syncedLabel: string;

  metrics: AnalyticsMetric[];

  daily: DailyVolume[];
  completedTotal: string;
  unresolvedTotal: string;
  chartNote: string;
  variance: string;

  funnelConversion: string;
  funnel: FunnelStage[];

  matchingHeadline: string;
  matchingRows: RateRow[];
  matchingNote: string;

  pickupHeadline: string;
  pickupRows: RateRow[];
  pickupNote: string;

  interventions: InterventionStat[];
  interventionNote: string;

  bottlenecks: Bottleneck[];

  sectors: SectorRow[];
  sectorNote: string;

  insightTitle: string;
  insightBody: string[];
  recommendation: string;
}
