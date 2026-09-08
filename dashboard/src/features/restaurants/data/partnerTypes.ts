/** Domain types behind the Restaurant Partners directory. */

export type PartnerStatus = 'active' | 'attention' | 'inactive';

export const PARTNER_STATUS_LABEL: Record<PartnerStatus, string> = {
  active: 'Active',
  attention: 'Attention',
  inactive: 'Inactive',
};

/** One row in the partner table. */
export interface PartnerRow {
  id: string;
  name: string;
  /** Two-letter avatar mark. */
  initials: string;
  location: string;
  status: PartnerStatus;
  activeRescues: number;
  completed: number;
  /** "2 min ago". */
  lastActivity: string;
}

/** One entry in the dossier's recent activity list. */
export interface PartnerActivity {
  when: string;
  title: string;
  /** "Rescue #FL-20481 · 25 meal boxes". */
  subject: string;
  detail: string;
  /** The rescue this entry points at, when it has one. */
  rescueId?: string;
}

/** The right-hand dossier for the selected partner. */
export interface PartnerDossier {
  id: string;
  verified: boolean;
  branchLine: string;
  successRate: string;
  participation: string;
  pickupReadiness: string;
  incidents: string;
  healthLabel: string;
  activity: PartnerActivity[];
}

/** Everything the directory page renders. */
export interface PartnerDirectory {
  totals: {
    all: number;
    active: number;
    attention: number;
    inactive: number;
  };
  locations: string[];
  rows: PartnerRow[];
  page: number;
  pageCount: number;
  dossiers: Record<string, PartnerDossier>;
}
