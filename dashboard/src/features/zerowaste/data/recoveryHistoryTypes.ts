/**
 * Domain types behind Recovery History.
 *
 * Follows the Stitch design (`0cfa0a7d733d45f3b5142b0a442db1f8`), which speaks
 * in completed **recovery records** rather than open cases: what was diverted,
 * to whom, and how it ended.
 */

/** How a recovery record finished. */
export type RecoveryOutcome = 'completed' | 'cancelled' | 'failed';

export const OUTCOME_LABEL: Record<RecoveryOutcome, string> = {
  completed: 'Completed',
  cancelled: 'Cancelled',
  failed: 'Failed',
};

/**
 * Coarse day bucket, so the design's Date control can actually filter.
 *
 * The records carry a sortable `at` timestamp as well; this is only what the
 * date control groups on, matching the "Today / Yesterday" wording the design
 * uses in its Completed column.
 */
export type DayBucket = 'today' | 'yesterday' | 'earlier';

export const DAY_LABEL: Record<DayBucket, string> = {
  today: 'Today',
  yesterday: 'Yesterday',
  earlier: 'Earlier',
};

/** One row in the history table. */
export interface RecoveryRecord {
  id: string;
  source: string;
  partner: string;
  /** The design's own wording: "Organic Recovery", "Biogas Recovery". */
  type: string;
  outcome: RecoveryOutcome;
  /** "Today, 10:42 AM" - rendered verbatim in the Completed column. */
  completedLabel: string;
  day: DayBucket;
  /** ISO-8601, used only for ordering. */
  at: string;

  /** Everything the detail panel shows. */
  detail: {
    food: string;
    route: string;
    handover: string;
    notes: string;
    /** The recovery partner this record points at, when it has one. */
    partnerId?: string;
  };
}

export interface RecoveryHistory {
  records: RecoveryRecord[];
}
