import type { RecoveryHistory } from './recoveryHistoryTypes';

/**
 * Fixtures behind Recovery History, taken from the Stitch design
 * (`0cfa0a7d733d45f3b5142b0a442db1f8`).
 *
 * **PHASE 14: delete this file.** The page takes a `RecoveryHistory` prop.
 *
 * The four records, their sources, partners, types, outcomes and timestamps
 * are the mock's own, as is the status note on RW-1024. The three records the
 * design does not detail carry notes written to match their outcome, since a
 * cancelled or failed record with no explanation would be the one thing an
 * operator actually opens this page to read.
 */
export const SAMPLE_RECOVERY_HISTORY: RecoveryHistory = {
  records: [
    {
      id: 'RW-1024',
      source: 'Green Leaf Kitchen',
      partner: 'GreenCycle Recovery',
      type: 'Organic Recovery',
      outcome: 'completed',
      completedLabel: 'Today, 10:42 AM',
      day: 'today',
      at: '2026-09-08T10:42:00Z',
      detail: {
        food: '25 prepared meal boxes',
        route: 'Downtown District to North Zone',
        handover: 'Confirmed',
        notes:
          'Recovery executed successfully within the optimal temperature threshold and time window.',
        partnerId: 'RP-204',
      },
    },
    {
      id: 'RW-1021',
      source: 'Sunrise Catering',
      partner: 'Community Food Hub',
      type: 'Food Recovery',
      outcome: 'completed',
      completedLabel: 'Today, 09:18 AM',
      day: 'today',
      at: '2026-09-08T09:18:00Z',
      detail: {
        food: '14 bread trays and 6 produce crates',
        route: 'Central District to Central District',
        handover: 'Confirmed',
        notes:
          'Collected 22 minutes inside the pickup window. Handover PIN matched on first scan.',
        partnerId: 'RP-118',
      },
    },
    {
      id: 'RW-1018',
      source: 'Central Kitchen',
      partner: 'BioRenew Energy',
      type: 'Biogas Recovery',
      outcome: 'cancelled',
      completedLabel: 'Yesterday, 6:24 PM',
      day: 'yesterday',
      at: '2026-09-07T18:24:00Z',
      detail: {
        food: '32 kg mixed prepared food',
        route: 'North Zone to North Zone',
        handover: 'Not attempted',
        notes:
          'Cancelled by operator after the source partner recovered the surplus through a late direct rescue. No vehicle was dispatched.',
        partnerId: 'RP-302',
      },
    },
    {
      id: 'RW-1014',
      source: 'Harbor Events',
      partner: 'Northside Compost',
      type: 'Organic Recovery',
      outcome: 'failed',
      completedLabel: 'Yesterday, 4:12 PM',
      day: 'yesterday',
      at: '2026-09-07T16:12:00Z',
      detail: {
        food: '58 kg packaged ready meals',
        route: 'Downtown District to East District',
        handover: 'Not completed',
        notes:
          'Partner refused the load on arrival: packaging could not be separated on site. The consignment reached landfill, and the routing rule that placed it is under review.',
        partnerId: 'RP-127',
      },
    },
  ],
};
