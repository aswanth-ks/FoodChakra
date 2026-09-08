import type { AnalyticsData, DailyVolume } from './analyticsTypes';

/**
 * Fixtures behind the Analytics page, from the Stitch design.
 *
 * **PHASE 14: delete this file.** The page takes an `AnalyticsData` prop.
 */

/** 30 days of volume, shaped to the design's steady curve with mild noise. */
const DAILY: DailyVolume[] = Array.from({ length: 30 }, (_, index) => {
  // A gentle upward drift with a weekly ripple, so the chart reads as
  // "stable with minimal drop-off" like the design's own footnote says.
  const base = 36 + index * 0.5;
  const ripple = Math.sin(index / 2.4) * 4;
  const completed = Math.round(base + ripple);
  const unresolved = Math.max(1, Math.round(3 + Math.cos(index / 3) * 1.6));
  return { completed, unresolved };
});

export const SAMPLE_ANALYTICS: AnalyticsData = {
  contextLabel: 'Consolidated Fleet Operations',
  reportingWindow: 'Reporting Window: Prior 30 Days',
  scopes: ['All Sectors', 'Direct Hubs', 'Micro-Pickups'],
  syncedLabel: 'Data sync: 2m ago',

  metrics: [
    {
      label: 'Rescue Success Rate',
      icon: 'verified',
      value: '94.2%',
      delta: '+2.1%',
      improved: true,
      direction: 'up',
      caption: 'vs. previous period (92.1%)',
    },
    {
      label: 'Avg Matching Time',
      icon: 'timer',
      value: '11 min',
      delta: '-1.8 min',
      improved: true,
      direction: 'down',
      caption: 'Median: 9.4 min dispatch queue',
    },
    {
      label: 'Avg Pickup Time',
      icon: 'route',
      value: '18 min',
      delta: '-2.4 min',
      improved: true,
      direction: 'down',
      caption: 'Pickup windows strictly enforced',
    },
    {
      label: 'Completed Rescues',
      icon: 'inventory_2',
      value: '1,284',
      delta: '+8.4%',
      improved: true,
      direction: 'up',
      caption: '1,420 total surplus published',
    },
  ],

  daily: DAILY,
  completedTotal: '1,284 total',
  unresolvedTotal: '78 total',
  chartNote:
    'Rescue completion has remained stable over the selected period with ' +
    'minimal drop-off anomalies.',
  variance: 'Variance: ±1.2%',

  funnelConversion: '90.4%',
  funnel: [
    {
      step: 'Step 01',
      title: 'Surplus Published',
      count: '1,420',
      caption: 'Logged in registry',
      percent: 100,
      handoff: '95.9% to dispatch',
    },
    {
      step: 'Step 02',
      title: 'Search Started',
      count: '1,362',
      caption: 'Dispatched to network',
      percent: 95.9,
      handoff: '96.8% claimed',
    },
    {
      step: 'Step 03',
      title: 'Matched',
      count: '1,318',
      caption: 'Rescuer accepted',
      percent: 92.8,
      handoff: '97.4% on site',
    },
    {
      step: 'Step 04',
      title: 'Pickup',
      count: '1,284',
      caption: 'En route / verified',
      percent: 90.4,
      handoff: '100% completion',
    },
    {
      step: 'Step 05',
      title: 'Completed',
      count: '1,284',
      caption: 'Final handovers done',
      percent: 90.4,
    },
  ],

  matchingHeadline: '11 min',
  matchingRows: [
    {
      label: 'Rescues matched within 10 min',
      percent: 78,
      caption: 'Primary operational target threshold (≥ 75%)',
      positive: true,
    },
    {
      label: 'Rescues requiring escalation',
      percent: 7,
      caption: 'Manual operator intervention required',
    },
    {
      label: 'Rescues requiring extended coverage',
      percent: 2,
      caption: 'Geographic boundary re-dispatch',
    },
  ],
  matchingNote:
    'Standard dispatch window is 15 minutes before trigger rule escalation.',

  pickupHeadline: '18 min',
  pickupRows: [
    {
      label: 'Pickups completed within window',
      percent: 91,
      caption: '1,168 pickups checked in before cutoff',
      positive: true,
    },
    {
      label: 'Pickup delays',
      percent: 6,
      caption: 'Delayed by >10 min beyond scheduled window',
    },
    {
      label: 'Rescuer cancellations',
      percent: 3,
      caption: 'Immediate reassignment successfully triggered',
    },
  ],
  pickupNote: 'Average delay resolution time across fleet: 4.2 minutes.',

  interventions: [
    { label: 'Total Escalations', value: '42', caption: '2.9% of total logs' },
    {
      label: 'Resolved Post-Escalation',
      value: '36',
      caption: '85.7% recovery efficiency',
    },
    {
      label: 'Still Unresolved',
      value: '3',
      caption: '7.1% under investigation',
      tone: 'critical',
    },
    {
      label: 'Alternative Recovery',
      value: '3',
      caption: '7.1% zero-waste routed',
    },
  ],
  interventionNote:
    'Fallback routing ensures zero unmanaged surplus across local sectors.',

  bottlenecks: [
    {
      rank: 1,
      title: 'Rescuer availability',
      caption: 'Most frequent cause of dispatch escalation',
      percent: 38,
    },
    {
      rank: 2,
      title: 'Pickup window pressure',
      caption: 'Frequently observed during high-demand restaurant shifts',
      percent: 29,
    },
    {
      rank: 3,
      title: 'Rescuer cancellation',
      caption: 'Requires immediate secondary coverage dispatch',
      percent: 21,
    },
    {
      rank: 4,
      title: 'High surplus volume',
      caption: 'More common during catering & event periods',
      percent: 12,
    },
  ],

  sectors: [
    { area: 'Downtown', rescues: 248, successRate: '96%', avgMatch: '8 min', status: 'Healthy' },
    { area: 'Central District', rescues: 186, successRate: '91%', avgMatch: '13 min', status: 'Monitor' },
    { area: 'North Zone', rescues: 142, successRate: '88%', avgMatch: '16 min', status: 'Needs attention' },
    { area: 'South Zone', rescues: 121, successRate: '95%', avgMatch: '10 min', status: 'Healthy' },
  ],
  sectorNote: 'Displaying operational data for prioritized metro zones',

  insightTitle: 'Courier Density Shift',
  insightBody: [
    'Rescue demand increased significantly during evening pickup windows ' +
      '(6:00 PM – 8:00 PM).',
    'Matching time was highest in North Zone due to courier density ' +
      'thresholds falling below the 4-courier minimum.',
  ],
  recommendation:
    'Recommended re-allocation of 6 couriers from Central District to North ' +
    'Zone for 17:30 cutoff.',
};
