/** Domain types behind the Operations Console Overview. */

/** How a KPI card reads at a glance. */
export type KpiTone = 'nominal' | 'neutral' | 'warning' | 'critical';

export interface Kpi {
  label: string;
  value: string;
  tone: KpiTone;
  /** Right-hand note beside the number, e.g. "+8% vs yday". */
  note: string;
  /** Material Symbols name shown before [note], when there is one. */
  noteIcon?: string;
  /** Bottom line of the card. */
  caption: string;
  captionIcon?: string;
  /** Renders [note] as a solid badge rather than plain text. */
  noteAsBadge?: boolean;
}

/** Severity of a case sitting in the priority queue. */
export type CaseSeverity = 'critical' | 'attention';

export interface PriorityCase {
  id: string;
  title: string;
  /** "Green Leaf Kitchen · Metro Central". */
  source: string;
  severity: CaseSeverity;
  /** Minutes until the pickup window closes. */
  minutesRemaining: number;
  timerIcon: string;
  /** "No rescuer matched". */
  status: string;
  /** "Route ID #RQ-9041" / "Assigned: Rescuer #R-118". */
  detail: string;
  /** The action button's label. */
  actionLabel: string;
}

/** A node plotted on the network map. */
export type MapNodeKind = 'matched' | 'attention' | 'critical' | 'idle';

export interface MapNode {
  id: string;
  x: number;
  y: number;
  kind: MapNodeKind;
  /** Shown in the node's title, e.g. "Staged Hub #04 · Idle". */
  info: string;
  /** Countdown label anchored under the node, when it has one. */
  callout?: string;
}

/** A routing vector drawn between nodes. */
export interface MapRoute {
  id: string;
  /** SVG path data, in the design's 880x480 viewBox. */
  d: string;
  tone: 'matched' | 'attention';
}

export interface HealthMetric {
  label: string;
  icon: string;
  value: string;
  note: string;
  /** Green when the metric is a success measure rather than a duration. */
  positive?: boolean;
  /** Normalised 0-1 samples for the sparkline. */
  trend: number[];
}

export type EventKind =
  | 'matched'
  | 'completed'
  | 'escalation'
  | 'published'
  | 'verified';

export interface NetworkEvent {
  /** Wall-clock stamp as shown in the design, e.g. "18:42". */
  time: string;
  kind: EventKind;
  title: string;
  /** "Green Leaf Kitchen · 25 Meal Boxes". */
  subject: string;
  /** Parenthetical detail line. */
  note: string;
  /** "2m ago". */
  ago: string;
}

/** Everything the Overview page renders. */
export interface OverviewData {
  sectors: string[];
  kpis: Kpi[];
  legend: { label: string; kind: MapNodeKind }[];
  mapNodes: MapNode[];
  mapRoutes: MapRoute[];
  /** The banner across the bottom of the map. */
  broadcast: string;
  cases: PriorityCase[];
  /** "All other 39 rescues progressing normally". */
  queueFootnote: string;
  totalLiveQueue: number;
  health: HealthMetric[];
  events: NetworkEvent[];
}
