import type { EscalationData, QueueData } from './queueTypes';

/**
 * Fixtures behind the Rescue Queue and Smart Escalation pages, from the
 * Stitch designs.
 *
 * **PHASE 14: delete this file.** Both pages take their data as props.
 */

export const SAMPLE_QUEUE: QueueData = {
  kpis: [
    {
      label: 'Total Active',
      icon: 'inventory_2',
      value: '42',
      caption: 'across 4 active zones',
      tone: 'nominal',
    },
    {
      label: 'Critical',
      icon: 'emergency_home',
      value: '3',
      caption: 'Immediate review',
      tone: 'critical',
    },
    {
      label: 'Attention',
      icon: 'schedule',
      value: '8',
      caption: 'Monitor window',
      tone: 'warning',
    },
    {
      label: 'Pickup Approaching',
      icon: 'local_shipping',
      value: '8',
      caption: 'Under 15 min',
      tone: 'neutral',
    },
  ],

  filters: [
    { id: 'all', label: 'All', count: 42 },
    { id: 'critical', label: 'Critical', count: 3 },
    { id: 'attention', label: 'Attention', count: 8 },
    { id: 'searching', label: 'Searching', count: 14 },
    { id: 'matched', label: 'Matched', count: 12 },
    { id: 'approaching', label: 'Pickup Approaching', count: 8 },
    { id: 'completed', label: 'Completed', count: null },
  ],

  rows: [
    {
      id: 'FL-20481',
      priority: 'critical',
      quantityLabel: '25 meal boxes',
      restaurant: 'Green Leaf Kitchen',
      branch: 'Downtown Kitchen',
      state: 'No rescuer matched',
      stateIcon: 'error',
      minutesRemaining: 12,
      actionLabel: 'Open',
    },
    {
      id: 'FL-20479',
      priority: 'attention',
      quantityLabel: '8 meal boxes',
      restaurant: 'Sunrise Catering',
      branch: 'Westside Hub',
      state: 'Pickup approaching',
      stateIcon: 'near_me',
      minutesRemaining: 7,
      actionLabel: 'Open',
    },
    {
      id: 'FL-20475',
      priority: 'attention',
      quantityLabel: '18 portions',
      restaurant: 'Central Kitchen',
      branch: 'Midtown',
      state: 'Rescuer cancelled',
      stateIcon: 'person_cancel',
      minutesRemaining: 24,
      actionLabel: 'Open',
    },
    {
      id: 'FL-20473',
      priority: 'active',
      quantityLabel: '12 meal boxes',
      restaurant: 'Community Kitchen',
      branch: 'East Bay',
      state: 'Rescuer matched',
      stateIcon: 'check_circle',
      minutesRemaining: 31,
      actionLabel: 'Open',
    },
    {
      id: 'FL-20468',
      priority: 'active',
      quantityLabel: '20 portions',
      restaurant: 'Riverside Restaurant',
      branch: 'Harbor South',
      state: 'Fallback active',
      stateIcon: 'radar',
      minutesRemaining: 18,
      actionLabel: 'Open',
    },
    {
      id: 'FL-20461',
      priority: 'completed',
      quantityLabel: '15 meal boxes',
      restaurant: 'Northside Kitchen',
      branch: 'North Sector',
      state: 'Successfully collected',
      stateIcon: 'task_alt',
      minutesRemaining: null,
      actionLabel: 'View',
    },
  ],

  totalActive: 42,
  page: 1,
  pageCount: 7,

  inspection: {
    id: 'FL-20481',
    priority: 'critical',
    restaurant: 'Green Leaf Kitchen',
    address: '452 Elm Street, Downtown District',
    pickupWindow: '1:30 PM – 2:00 PM',
    minutesRemaining: 12,
    windowNote: 'Window closing soon · Strict cutoff',
    foodSummary: '25 meal boxes',
    foodNote: 'Prepared hot meals · Packed in compostable trays',
    statusTitle: 'Operational Status',
    statusBody:
      'Rescue escalation active — no community rescuer matched within ' +
      'primary or secondary radius.',
    handoverTitle: 'Alternative Recovery Available',
    handoverBody:
      'Rescue window expiring in 12 min. Handover to verified zero-waste ' +
      'diversion partners recommended.',
  },
};

export const SAMPLE_ESCALATION: EscalationData = {
  escalatingCount: 3,
  bannerBody:
    'FoodLoop automatically expands rescue coverage when a surplus ' +
    'opportunity remains unmatched within primary geographic bounds.',

  rows: [
    {
      id: 'FL-20481',
      quantityLabel: '25 meal boxes (Prepared Meals)',
      restaurant: 'Green Leaf Kitchen',
      locality: 'Downtown District',
      state: 'No rescuer matched',
      stateIcon: 'person_off',
      stageLabel: 'Stage 2 · Search expanded',
      minutesRemaining: 12,
      focused: true,
    },
    {
      id: 'FL-20486',
      quantityLabel: '8 meal boxes (Bakery & Pastries)',
      restaurant: 'Sunrise Catering',
      locality: 'Market Plaza',
      state: 'Pickup approaching',
      stateIcon: 'schedule',
      stageLabel: 'Stage 1 · Additional coverage',
      minutesRemaining: 7,
      focused: false,
    },
    {
      id: 'FL-20479',
      quantityLabel: '20 meal portions (Fresh Produce)',
      restaurant: 'Riverside Restaurant',
      locality: 'Waterfront South',
      state: 'Fallback search active',
      stateIcon: 'sync_alt',
      stageLabel: 'Stage 3 · Alternative recovery',
      minutesRemaining: 18,
      focused: false,
    },
  ],

  focusTitle: '25 Meal Boxes',
  focusLocality: 'Downtown District',
  focusPartner: 'Green Leaf Kitchen — Rescue #FL-20481',
  focusNote: 'Prepared Organic Lunches & Salads · Certified Clean Stored',
  savedLabel: 'Surplus Value Saved',
  savedValue: '~37.5 kg CO2e',

  issueTitle: 'Current Issue: No rescuer matched yet',
  issueBody:
    'Pickup window: Today · 1:30 PM – 2:00 PM (12 min remaining to preserve ' +
    'prepared meal temperatures)',

  currentStage: 3,
  stageCount: 5,
  stageSummary:
    'FoodLoop has expanded the rescue search to additional nearby coverage.',
  stages: [
    { index: 1, title: 'Normal Search', stamp: '1:20 PM · Dispatched' },
    { index: 2, title: 'Additional Coverage', stamp: '1:24 PM · Activated' },
    { index: 3, title: 'Search Expanded', stamp: '1:27 PM · Active' },
    { index: 4, title: 'Operator Review', stamp: '1:30 PM · Now Pending' },
    { index: 5, title: 'Alternative Recovery', stamp: 'Standby readiness' },
  ],

  telemetry: [
    {
      label: 'Rescue Perimeter',
      icon: 'explore',
      value: 'Tier-2 Radius',
      caption: '+2.5 km expanded',
    },
    {
      label: 'Targeted Fleet',
      icon: 'electric_moped',
      value: '18 Couriers',
      caption: 'Push notifications live',
    },
    {
      label: 'Shelter Redirection',
      icon: 'home_work',
      value: '3 Standby Hubs',
      caption: 'Within 10 min transit',
    },
  ],

  auditId: 'AUD-992-FL20481',
  events: [
    {
      heading: '1:30 PM · Operator review triggered',
      source: 'Automated SLA trigger',
      detail:
        'Rescue reached 12 min critical window without courier acceptance. ' +
        'Automatic escalation surfaced this case to desk operators.',
    },
    {
      heading: '1:27 PM · Search perimeter expanded',
      source: 'System Core',
      detail:
        'Automated escalation enabled tier-2 courier perimeter (+2.5km) ' +
        'including transit routes toward Financial District.',
    },
    {
      heading: '1:24 PM · Additional coverage activated',
      source: 'System Core',
      detail:
        'Surplus request broadcasted to priority reserve couriers within a ' +
        '5-minute standby radius.',
    },
    {
      heading: '1:20 PM · Rescue search initialized',
      source: 'Restaurant App',
      detail:
        'Green Leaf Kitchen finalized 25 prepared meal portions. Initial ' +
        'tier-1 matching algorithm dispatched.',
    },
  ],

  authorisation: 'Level 2 Authorized Intervention',
  pendingTitle: 'Pending Action: Expand rescue coverage',
  pendingBody:
    'FoodLoop will continue searching through additional rescue coverage ' +
    'across adjacent downtown zones and boost dispatcher incentives.',
  actions: [
    { icon: 'broadcast_on_personal', label: 'Expand rescue coverage' },
    { icon: 'support_agent', label: 'Contact rescue network coordinators' },
    { icon: 'electric_bike', label: 'Mark for priority manual dispatch' },
    { icon: 'food_bank', label: 'Start alternative recovery search' },
  ],
  dangerAction: {
    icon: 'block',
    label: 'Cancel rescue',
    caution:
      'Requires supervisor override confirmation and zero-waste disposal ' +
      'logging.',
  },

  principlesBody:
    'FoodLoop progressively expands rescue coverage when surplus food ' +
    'remains unmatched. If normal rescue matching does not succeed, the ' +
    'platform automatically increases courier radius and eventually ' +
    'searches for alternative recovery options.',
  principles: [
    {
      icon: 'bolt',
      title: '100% Automated Escalation Triggers',
      body: 'Triggered at predetermined intervals based on item shelf stability.',
    },
    {
      icon: 'visibility',
      title: 'Human Operator Supervision',
      body:
        'Desk operators possess direct override authority for route ' +
        'prioritization.',
    },
    {
      icon: 'recycling',
      title: 'Zero-Waste Destination Fallback',
      body:
        'Unclaimed meals immediately route to local community shelters and ' +
        'soup pantries.',
    },
  ],
};
