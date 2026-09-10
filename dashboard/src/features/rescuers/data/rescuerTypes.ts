/** Domain types behind Rescuers Management. */

/**
 * What a rescuer is doing right now.
 *
 * `on_rescue` and `available` are both "on shift"; `offline` is a known
 * account that is not working. `suspended` is an operator decision and is the
 * only state the console itself can cause.
 */
export type RescuerStatus = 'on_rescue' | 'available' | 'offline' | 'suspended';

export const RESCUER_STATUS_LABEL: Record<RescuerStatus, string> = {
  on_rescue: 'On Rescue',
  available: 'Available',
  offline: 'Offline',
  suspended: 'Suspended',
};

/** Verification state of the account's rescuer credentials. */
export type VerificationState = 'verified' | 'pending' | 'expired';

export const VERIFICATION_LABEL: Record<VerificationState, string> = {
  verified: 'Verified',
  pending: 'Pending review',
  expired: 'Expired',
};

/** One row in the rescuer table. */
export interface RescuerRow {
  id: string;
  name: string;
  /** Two-letter avatar mark. */
  initials: string;
  zone: string;
  status: RescuerStatus;
  verification: VerificationState;
  /** The rescue currently held, when the rescuer is on one. */
  currentRescueId?: string;
  completed: number;
  /** Completion rate as shown, e.g. "97.4%". */
  reliability: string;
  /** "2 min ago". */
  lastSeen: string;
}

/** One entry in the dossier's recent activity list. */
export interface RescuerActivity {
  when: string;
  title: string;
  subject: string;
  detail: string;
  rescueId?: string;
}

/** The right-hand dossier for the selected rescuer. */
export interface RescuerDossier {
  id: string;
  joined: string;
  /** "Bicycle · 12 kg capacity". */
  transport: string;
  avgPickupTime: string;
  acceptanceRate: string;
  cancellations: string;
  /** Distance covered in the trailing 30 days. */
  distance: string;
  /** Free-text summary of standing, shown against the verification chip. */
  standing: string;
  activity: RescuerActivity[];
}

/** Everything the Rescuers page renders. */
export interface RescuerDirectory {
  totals: {
    all: number;
    onRescue: number;
    available: number;
    offline: number;
    suspended: number;
  };
  zones: string[];
  rows: RescuerRow[];
  page: number;
  pageCount: number;
  dossiers: Record<string, RescuerDossier>;
}
