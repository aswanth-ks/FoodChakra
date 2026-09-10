import type { ActivityLog } from './activityTypes';

/**
 * Fixtures behind the Activity Log.
 *
 * **PHASE 14: delete this file.** The page takes an `ActivityLog` prop.
 *
 * The entries deliberately reference the same rescues, zones and partners the
 * other console pages use, so the log reads as the history of this network
 * rather than an unrelated stream. The `at` timestamps are fixed rather than
 * generated: an audit log whose contents move every time the page renders
 * would be lying about when things happened.
 */
export const SAMPLE_ACTIVITY: ActivityLog = {
  totals: { all: 1284, operator: 62, system: 1198, failed: 4 },

  ranges: ['Last 24 hours', 'Last 7 days', 'Last 30 days'],

  entries: [
    {
      id: 'EV-90412',
      at: '2026-09-08T14:02:41Z',
      clock: '14:02:41 UTC',
      relative: '6 min ago',
      actorKind: 'system',
      actor: 'Smart Escalation',
      action: 'Expanded rescue coverage',
      target: 'North Zone (ZN-03)',
      category: 'coverage',
      outcome: 'ok',
      detail:
        'Coverage radius widened from 3.0 km to 5.5 km after four rescues went unmatched inside the standard band during the evening peak.',
      source: 'escalation-worker-1',
    },
    {
      id: 'EV-90408',
      at: '2026-09-08T13:58:12Z',
      clock: '13:58:12 UTC',
      relative: '11 min ago',
      actorKind: 'rescuer',
      actor: 'Amara Okonkwo (RS-4821)',
      action: 'Accepted rescue',
      target: 'Rescue #FL-20481',
      category: 'rescue',
      outcome: 'ok',
      detail:
        'Rescue accepted 92 seconds after dispatch. 25 meal boxes, Green Leaf Kitchen to Downtown Shelter.',
      rescueId: 'FL-20481',
    },
    {
      id: 'EV-90401',
      at: '2026-09-08T13:44:03Z',
      clock: '13:44:03 UTC',
      relative: '25 min ago',
      actorKind: 'operator',
      actor: 'ops-desk-2',
      action: 'Flagged zone as strained',
      target: 'East District (ZN-04)',
      category: 'escalation',
      outcome: 'warning',
      detail:
        'Partner-to-rescuer ratio crossed the 1.6 threshold. Zone added to the rescuer recruitment shortlist.',
      source: 'console web - 10.4.2.18',
    },
    {
      id: 'EV-90396',
      at: '2026-09-08T13:31:55Z',
      clock: '13:31:55 UTC',
      relative: '37 min ago',
      actorKind: 'partner',
      actor: 'Sunrise Catering (PT-1082)',
      action: 'Published surplus',
      target: 'Rescue #FL-20477',
      category: 'rescue',
      outcome: 'ok',
      detail:
        '8 bread trays published with a 90 minute pickup window. Matched to a rescuer in 3.4 minutes.',
      rescueId: 'FL-20477',
    },
    {
      id: 'EV-90390',
      at: '2026-09-08T13:12:47Z',
      clock: '13:12:47 UTC',
      relative: '56 min ago',
      actorKind: 'system',
      actor: 'Dispatch',
      action: 'Rescue dispatch failed',
      target: 'Rescue #FL-20470',
      category: 'rescue',
      outcome: 'failed',
      detail:
        'No rescuer accepted within the standard band before the window closed. Handed to the Zero-Waste Network fallback queue.',
      source: 'dispatch-worker-3',
      rescueId: 'FL-20470',
    },
    {
      id: 'EV-90385',
      at: '2026-09-08T12:49:20Z',
      clock: '12:49:20 UTC',
      relative: '1 h 19 min ago',
      actorKind: 'operator',
      actor: 'ops-desk-1',
      action: 'Signed in',
      target: 'Operations Console',
      category: 'auth',
      outcome: 'ok',
      detail: 'Session opened for the EU-WEST region.',
      source: 'console web - 10.4.2.11',
    },
    {
      id: 'EV-90377',
      at: '2026-09-08T12:20:08Z',
      clock: '12:20:08 UTC',
      relative: '1 h 48 min ago',
      actorKind: 'system',
      actor: 'Handover verification',
      action: 'Verified handover',
      target: 'Rescue #FL-20455',
      category: 'rescue',
      outcome: 'ok',
      detail:
        'Handover PIN matched at the distribution point. 20 meal boxes delivered 14 minutes inside the window.',
      rescueId: 'FL-20455',
    },
    {
      id: 'EV-90361',
      at: '2026-09-08T11:37:44Z',
      clock: '11:37:44 UTC',
      relative: '2 h 31 min ago',
      actorKind: 'operator',
      actor: 'ops-desk-2',
      action: 'Suspended rescuer account',
      target: 'Marcus Bell (RS-5122)',
      category: 'account',
      outcome: 'warning',
      detail:
        'Third no-show on an accepted rescue within 14 days. Rescue #FL-20330 reassigned under expanded coverage.',
      source: 'console web - 10.4.2.18',
      rescueId: 'FL-20330',
    },
    {
      id: 'EV-90344',
      at: '2026-09-08T10:55:31Z',
      clock: '10:55:31 UTC',
      relative: '3 h 13 min ago',
      actorKind: 'system',
      actor: 'Registry check',
      action: 'Partner onboarding blocked',
      target: 'Harbour Mission Kitchen',
      category: 'account',
      outcome: 'failed',
      detail:
        'Registration collided with an existing partner record on the same domain. Onboarding stopped at step 3 with a 409.',
      source: 'onboarding-service',
    },
    {
      id: 'EV-90312',
      at: '2026-09-08T09:14:02Z',
      clock: '09:14:02 UTC',
      relative: '4 h 54 min ago',
      actorKind: 'operator',
      actor: 'ops-desk-3',
      action: 'Paused dispatch in zone',
      target: 'Harbour Fringe (ZN-06)',
      category: 'coverage',
      outcome: 'ok',
      detail:
        'Pilot ended below the partner density target. No new rescues dispatched in this zone.',
      source: 'console web - 10.4.2.24',
    },
  ],
};
