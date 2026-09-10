/** Domain types behind the Activity Log. */

/**
 * Who or what caused the entry.
 *
 * The distinction matters for accountability: `operator` is a named person at
 * a console, `system` is automation acting on its own rules, `partner` and
 * `rescuer` are the apps. An audit log that blurs these cannot answer "who
 * decided this".
 */
export type ActorKind = 'operator' | 'system' | 'partner' | 'rescuer';

export const ACTOR_LABEL: Record<ActorKind, string> = {
  operator: 'Operator',
  system: 'System',
  partner: 'Partner',
  rescuer: 'Rescuer',
};

/** What kind of thing happened. */
export type EventCategory =
  | 'rescue'
  | 'escalation'
  | 'coverage'
  | 'account'
  | 'auth';

export const CATEGORY_LABEL: Record<EventCategory, string> = {
  rescue: 'Rescue',
  escalation: 'Escalation',
  coverage: 'Coverage',
  account: 'Account',
  auth: 'Access',
};

/** How the entry ended. */
export type EventOutcome = 'ok' | 'warning' | 'failed';

export const OUTCOME_LABEL: Record<EventOutcome, string> = {
  ok: 'Success',
  warning: 'Warning',
  failed: 'Failed',
};

/** One row in the activity log. */
export interface ActivityEntry {
  /** Audit id, e.g. "EV-90412". */
  id: string;
  /** ISO-8601 UTC, rendered as both absolute and relative time. */
  at: string;
  /** "14:02:41 UTC" as the log renders it. */
  clock: string;
  /** "6 min ago". */
  relative: string;
  actorKind: ActorKind;
  /** "ops-desk-2" / "Smart Escalation" / "Green Leaf Kitchen". */
  actor: string;
  /** The imperative summary: "Expanded rescue coverage". */
  action: string;
  /** What it acted on: "Rescue #FL-20481". */
  target: string;
  category: EventCategory;
  outcome: EventOutcome;
  /** Full sentence shown in the inspection panel. */
  detail: string;
  /** Source of the call, shown for operator actions. */
  source?: string;
  /** The rescue this entry points at, when it has one. */
  rescueId?: string;
}

/** Everything the Activity Log page renders. */
export interface ActivityLog {
  totals: {
    all: number;
    operator: number;
    system: number;
    failed: number;
  };
  /** Selectable ranges; the first is the default. */
  ranges: string[];
  entries: ActivityEntry[];
}
