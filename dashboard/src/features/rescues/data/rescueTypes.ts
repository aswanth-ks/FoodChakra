/** Domain types behind Live Rescue Map and Rescue Opportunity Detail. */

/** Operational severity, shared by the map markers, list and filters. */
export type RescueSeverity = 'critical' | 'attention' | 'active' | 'completed';

/** The nine lifecycle steps a rescue moves through. */
export type LifecycleStep =
  | 'draft'
  | 'published'
  | 'searching'
  | 'matched'
  | 'onTheWay'
  | 'arrived'
  | 'verified'
  | 'collected'
  | 'completed';

/** Ordered for the horizontal tracker; the index doubles as progress. */
export const LIFECYCLE_ORDER: LifecycleStep[] = [
  'draft',
  'published',
  'searching',
  'matched',
  'onTheWay',
  'arrived',
  'verified',
  'collected',
  'completed',
];

export const LIFECYCLE_LABEL: Record<LifecycleStep, string> = {
  draft: 'DRAFT',
  published: 'PUBLISHED',
  searching: 'SEARCHING',
  matched: 'MATCHED',
  onTheWay: 'ON THE WAY',
  arrived: 'ARRIVED',
  verified: 'VERIFIED',
  collected: 'COLLECTED',
  completed: 'COMPLETED',
};

/** One rescue as it appears on the map and in the side list. */
export interface RescueSummary {
  id: string;
  /** "Green Leaf Kitchen". */
  partner: string;
  severity: RescueSeverity;
  /** "18 boxes". */
  quantityLabel: string;
  /** Minutes until the pickup window closes. */
  minutesRemaining: number;
  /** "Downtown District · 0.4 km away". */
  locality: string;
  /** Marker position in the map's 900x560 viewBox. */
  x: number;
  y: number;
}

/** One step's state on the detail page's tracker. */
export interface LifecycleEntry {
  step: LifecycleStep;
  /** "1:15 PM", "12m left", or "Pending". */
  stamp: string;
}

/** A labelled fact in the surplus card. */
export interface DetailFact {
  label: string;
  value: string;
}

/** One operator action button on the detail page. */
export interface OperatorAction {
  icon: string;
  label: string;
  /** Shown under the label on the destructive action. */
  caution?: string;
  destructive?: boolean;
}

/** One entry in the audit log. */
export interface AuditEntry {
  title: string;
  time: string;
  detail: string;
}

/** One choice in the intervention drawer. */
export interface InterventionOption {
  id: string;
  title: string;
  description: string;
  /** "Estimated courier arrival: 7-9 minutes". */
  footnote: string;
  recommended?: boolean;
}

/** Everything the Rescue Opportunity Detail page renders. */
export interface RescueDetail {
  id: string;
  /** "FL-20481". */
  reference: string;
  partner: string;
  severity: RescueSeverity;

  /** "RESCUE STATE: SEARCHING". */
  stateLabel: string;
  headline: string;
  bannerTitle: string;
  bannerBody: string;
  /** "Auto-timeout trigger in 4m 18s". */
  autoTimeout: string;

  minutesRemaining: number;
  /** Total length of the pickup window, for the progress bar. */
  windowMinutes: number;
  windowOpens: string;
  windowCloses: string;

  lifecycle: LifecycleEntry[];

  quantityLabel: string;
  surplusFacts: DetailFact[];
  safetyNote: string;

  partnerAddress: string;
  partnerTier: string;
  partnerVerified: boolean;
  operatorNote: string;

  escalationTags: { icon: string; label: string }[];
  escalationBody: string;

  privilegeLabel: string;
  actions: OperatorAction[];

  audit: AuditEntry[];

  interventionTrigger: string;
  interventionTriggerBody: string;
  interventionOptions: InterventionOption[];
}

/** Counters for the bottom status strip and the map's summary row. */
export interface NetworkStatus {
  activeRescues: number;
  needIntervention: number;
  pickupsApproaching: number;
  regionCoverage: string;
  avgDispatch: string;
  rescuersOnline: string;
  consoleVersion: string;
}

/** "1h 10m left" / "25m left". */
export function formatRemaining(minutes: number): string {
  if (minutes >= 60) {
    const hours = Math.floor(minutes / 60);
    const rest = minutes % 60;
    return rest === 0 ? `${hours}h left` : `${hours}h ${rest}m left`;
  }
  return `${minutes}m left`;
}
