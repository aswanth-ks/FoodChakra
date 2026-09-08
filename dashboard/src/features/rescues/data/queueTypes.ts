import type { RescueSeverity } from './rescueTypes';

/** Domain types behind the Rescue Queue and Smart Escalation pages. */

/** The queue's priority column. `completed` is a closed row. */
export type QueuePriority = RescueSeverity;

/** One row in the operational queue table. */
export interface QueueRow {
  id: string;
  priority: QueuePriority;
  /** "25 meal boxes". */
  quantityLabel: string;
  restaurant: string;
  /** "Downtown Kitchen". */
  branch: string;
  /** "No rescuer matched". */
  state: string;
  stateIcon: string;
  /** Null on a completed row, which shows "Done" instead. */
  minutesRemaining: number | null;
  /** "Open" / "View". */
  actionLabel: string;
}

/** The inspection panel beside the queue. */
export interface QueueInspection {
  id: string;
  priority: QueuePriority;
  restaurant: string;
  address: string;
  pickupWindow: string;
  minutesRemaining: number;
  windowNote: string;
  foodSummary: string;
  foodNote: string;
  statusTitle: string;
  statusBody: string;
  handoverTitle: string;
  handoverBody: string;
}

/** Everything the Rescue Queue page renders. */
export interface QueueData {
  kpis: {
    label: string;
    icon: string;
    value: string;
    caption: string;
    tone: 'nominal' | 'critical' | 'warning' | 'neutral';
  }[];
  /** Filter chips with their counts; `null` count renders no number. */
  filters: { id: string; label: string; count: number | null }[];
  rows: QueueRow[];
  totalActive: number;
  page: number;
  pageCount: number;
  inspection: QueueInspection;
}

/* ------------------------------------------------------------ escalation */

/** One of the five escalation stages. */
export interface EscalationStage {
  index: number;
  title: string;
  /** "1:20 PM · Dispatched" or "Standby readiness". */
  stamp: string;
}

/** One row in the active escalations table. */
export interface EscalationRow {
  id: string;
  quantityLabel: string;
  restaurant: string;
  locality: string;
  state: string;
  stateIcon: string;
  /** "Stage 2 · Search expanded". */
  stageLabel: string;
  minutesRemaining: number;
  /** True for the row currently being inspected. */
  focused: boolean;
}

/** One telemetry tile under the tracker. */
export interface TelemetryTile {
  label: string;
  icon: string;
  value: string;
  caption: string;
}

/** One entry in the escalation audit feed. */
export interface EscalationEvent {
  /** "1:30 PM · Operator review triggered". */
  heading: string;
  /** "Automated SLA trigger". */
  source: string;
  detail: string;
}

/** One "how it works" point. */
export interface EscalationPrinciple {
  icon: string;
  title: string;
  body: string;
}

/** Everything the Smart Escalation page renders. */
export interface EscalationData {
  escalatingCount: number;
  bannerBody: string;

  rows: EscalationRow[];

  focusTitle: string;
  focusLocality: string;
  focusPartner: string;
  focusNote: string;
  savedLabel: string;
  savedValue: string;

  issueTitle: string;
  issueBody: string;

  currentStage: number;
  stageCount: number;
  stageSummary: string;
  stages: EscalationStage[];

  telemetry: TelemetryTile[];
  auditId: string;
  events: EscalationEvent[];

  authorisation: string;
  pendingTitle: string;
  pendingBody: string;
  actions: { icon: string; label: string }[];
  dangerAction: { icon: string; label: string; caution: string };

  principlesBody: string;
  principles: EscalationPrinciple[];
}
