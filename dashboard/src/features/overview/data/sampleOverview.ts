import type { OverviewData } from './overviewTypes';

/**
 * Fixture data behind the Overview page, taken from the Stitch design.
 *
 * **PHASE 14: delete this file.** The page takes an `OverviewData` as a prop,
 * so swapping in a live query is a change at the route, not in the page.
 */
export const SAMPLE_OVERVIEW: OverviewData = {
  sectors: [
    'Central Metro',
    'North Logistics Corridor',
    'East Riverside',
    'South Hub Basin',
  ],

  kpis: [
    {
      label: 'Active Rescues',
      value: '42',
      tone: 'nominal',
      note: '+8% vs yday',
      noteIcon: 'arrow_upward',
      caption: '34 matched & in transit',
    },
    {
      label: 'Awaiting Rescuer',
      value: '17',
      tone: 'neutral',
      note: 'Within target window',
      caption: 'Requires monitoring',
      captionIcon: 'hourglass_empty',
    },
    {
      label: 'Pickup Approaching',
      value: '8',
      tone: 'warning',
      note: '<30m cutoff',
      noteIcon: 'schedule',
      caption: 'Next 30 minutes',
    },
    {
      label: 'Needs Intervention',
      value: '3',
      tone: 'critical',
      note: 'PRIORITY',
      noteAsBadge: true,
      caption: 'Action required immediately',
      captionIcon: 'warning',
    },
  ],

  legend: [
    { label: 'Active (29)', kind: 'matched' },
    { label: 'Attention (8)', kind: 'attention' },
    { label: 'Critical (3)', kind: 'critical' },
    { label: 'Standby Rescuers (14)', kind: 'idle' },
  ],

  mapRoutes: [
    { id: 'g1', d: 'M 160,120 Q 260,135 340,115', tone: 'matched' },
    { id: 'g2', d: 'M 520,380 L 640,310', tone: 'matched' },
    { id: 'g3', d: 'M 330,290 Q 420,270 480,210', tone: 'matched' },
    { id: 'g4', d: 'M 700,100 L 750,170', tone: 'matched' },
    { id: 'a1', d: 'M 460,130 L 510,180', tone: 'attention' },
  ],

  mapNodes: [
    { id: 'n-g1', x: 340, y: 115, kind: 'matched', info: 'Route #RQ-8821 · In transit' },
    { id: 'n-g2', x: 640, y: 310, kind: 'matched', info: 'Route #RQ-8834 · In transit' },
    { id: 'n-g3', x: 480, y: 210, kind: 'matched', info: 'Route #RQ-8840 · In transit' },
    { id: 'n-g4', x: 750, y: 170, kind: 'matched', info: 'Route #RQ-8852 · In transit' },
    {
      id: 'n-a1',
      x: 510,
      y: 180,
      kind: 'attention',
      info: 'Sunrise Catering · Pickup approaching',
      callout: '7 min',
    },
    {
      id: 'n-a2',
      x: 330,
      y: 290,
      kind: 'attention',
      info: 'Central Kitchen · Re-dispatching',
      callout: '24 min',
    },
    {
      id: 'n-c1',
      x: 160,
      y: 120,
      kind: 'critical',
      info: 'Green Leaf Kitchen · No rescuer matched',
      callout: '12 min',
    },
    { id: 'n-i1', x: 220, y: 380, kind: 'idle', info: 'Staged Hub #04 · Idle' },
    { id: 'n-i2', x: 620, y: 420, kind: 'idle', info: 'Staged Hub #07 · Idle' },
    { id: 'n-i3', x: 790, y: 330, kind: 'idle', info: 'Standby rescuer · Available' },
    { id: 'n-i4', x: 100, y: 260, kind: 'idle', info: 'Standby rescuer · Available' },
  ],

  broadcast:
    'Rescue escalation active — additional rescue coverage enabled in Metro ' +
    'Central Sector (dynamic radius +2.4km)',

  cases: [
    {
      id: 'RQ-9041',
      title: '25 Meal Boxes',
      source: 'Green Leaf Kitchen · Metro Central',
      severity: 'critical',
      minutesRemaining: 12,
      timerIcon: 'timer',
      status: 'No rescuer matched',
      detail: 'Route ID #RQ-9041',
      actionLabel: 'Intervene',
    },
    {
      id: 'RQ-9042',
      title: '8 Meal Boxes',
      source: 'Sunrise Catering · Sector 02',
      severity: 'attention',
      minutesRemaining: 7,
      timerIcon: 'schedule',
      status: 'Pickup approaching',
      detail: 'Assigned: Rescuer #R-118',
      actionLabel: 'View',
    },
    {
      id: 'RQ-9043',
      title: '18 Meal Portions',
      source: 'Central Kitchen · Dock #2',
      severity: 'attention',
      minutesRemaining: 24,
      timerIcon: 'alarm',
      status: 'Rescuer cancelled — re-dispatching',
      detail: 'Auto-pinging 4 nearby rescuers',
      actionLabel: 'View',
    },
  ],

  queueFootnote: 'All other 39 rescues progressing normally',
  totalLiveQueue: 42,

  health: [
    {
      label: 'Rescue Success Rate',
      icon: 'verified',
      value: '94%',
      note: '+0.6% this week',
      positive: true,
      trend: [0.52, 0.58, 0.55, 0.66, 0.62, 0.74, 0.71, 0.82, 0.86, 0.9],
    },
    {
      label: 'Avg Matching Time',
      icon: 'timelapse',
      value: '11 min',
      note: 'Target <15 min',
      trend: [0.72, 0.68, 0.7, 0.61, 0.58, 0.6, 0.52, 0.5, 0.46, 0.44],
    },
    {
      label: 'Avg Pickup Time',
      icon: 'moped',
      value: '18 min',
      note: 'Target <25 min',
      trend: [0.6, 0.63, 0.58, 0.62, 0.55, 0.57, 0.53, 0.56, 0.5, 0.52],
    },
    {
      label: 'Fallback Activation',
      icon: 'alt_route',
      value: '2.4%',
      note: 'Zero-waste reroutes',
      trend: [0.3, 0.26, 0.34, 0.28, 0.22, 0.25, 0.2, 0.24, 0.18, 0.21],
    },
  ],

  events: [
    {
      time: '18:42',
      kind: 'matched',
      title: 'Rescuer matched',
      subject: 'Green Leaf Kitchen · 25 Meal Boxes',
      note: 'Rescuer #R-482 assigned via auto-dispatch',
      ago: '2m ago',
    },
    {
      time: '18:39',
      kind: 'completed',
      title: 'Pickup completed',
      subject: 'Central Kitchen · 12 Meal Portions',
      note: 'Delivered to Community Hub 4',
      ago: '5m ago',
    },
    {
      time: '18:34',
      kind: 'escalation',
      title: 'Escalation triggered',
      subject: 'Sunrise Catering · 8 Meal Boxes',
      note: 'Search expanded to +2.4km Sector 02',
      ago: '10m ago',
    },
    {
      time: '18:30',
      kind: 'published',
      title: 'Surplus published',
      subject: 'Green Leaf Kitchen · 25 Meal Boxes',
      note: 'Expiring in 45m · Intake verified',
      ago: '14m ago',
    },
    {
      time: '18:22',
      kind: 'verified',
      title: 'Handover verified',
      subject: 'Bistro Verde · 6 Surplus Packs',
      note: 'QR scan confirmed by Manager Lopez',
      ago: '22m ago',
    },
  ],
};
