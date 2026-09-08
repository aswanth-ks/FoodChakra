import type {
  NetworkStatus,
  RescueDetail,
  RescueSummary,
} from './rescueTypes';

/**
 * Fixture data behind the Live Rescue Map and Rescue Opportunity Detail,
 * taken from the Stitch designs.
 *
 * **PHASE 14: delete this file.** Both pages take their data as props, so
 * swapping in live queries is a change at the route, not in the pages.
 */

export const SAMPLE_RESCUES: RescueSummary[] = [
  {
    id: 'FL-20481',
    partner: 'Green Leaf Kitchen',
    severity: 'critical',
    quantityLabel: '25 boxes',
    minutesRemaining: 12,
    locality: 'Downtown District · 0.4 km away',
    x: 250,
    y: 200,
  },
  {
    id: 'FL-20482',
    partner: 'Sunrise Catering',
    severity: 'attention',
    quantityLabel: '18 boxes',
    minutesRemaining: 25,
    locality: 'Sector 02 · 1.2 km away',
    x: 520,
    y: 150,
  },
  {
    id: 'FL-20483',
    partner: 'Central Kitchen',
    severity: 'attention',
    quantityLabel: '40 boxes',
    minutesRemaining: 34,
    locality: 'Dock #2 · 2.0 km away',
    x: 380,
    y: 360,
  },
  {
    id: 'FL-20484',
    partner: 'Community Kitchen',
    severity: 'active',
    quantityLabel: '12 boxes',
    minutesRemaining: 70,
    locality: 'North Corridor · 3.1 km away',
    x: 690,
    y: 300,
  },
  {
    id: 'FL-20485',
    partner: 'Riverside Restaurant',
    severity: 'active',
    quantityLabel: '30 boxes',
    minutesRemaining: 105,
    locality: 'East Riverside · 4.4 km away',
    x: 620,
    y: 440,
  },
];

export const SAMPLE_NETWORK_STATUS: NetworkStatus = {
  activeRescues: 42,
  needIntervention: 3,
  pickupsApproaching: 8,
  regionCoverage: '94.2%',
  avgDispatch: '4.2 min',
  rescuersOnline: '38 online',
  consoleVersion: 'Console v4.8.2-prod',
};

export const SAMPLE_RESCUE_DETAIL: RescueDetail = {
  id: 'FL-20481',
  reference: 'FL-20481',
  partner: 'Green Leaf Kitchen',
  severity: 'critical',

  stateLabel: 'RESCUE STATE: SEARCHING',
  headline: 'No rescuer matched yet',
  bannerTitle: 'Operational status: Rescue escalation active',
  bannerBody:
    'Search has expanded to additional nearby rescue coverage. Time ' +
    'remaining until scheduled pickup window expiration is 12 minutes.',
  autoTimeout: 'Auto-timeout trigger in 4m 18s',

  minutesRemaining: 12,
  windowMinutes: 30,
  windowOpens: 'Started 1:30 PM',
  windowCloses: 'Closes 2:00 PM',

  lifecycle: [
    { step: 'draft', stamp: '1:15 PM' },
    { step: 'published', stamp: '1:18 PM' },
    { step: 'searching', stamp: '12m left' },
    { step: 'matched', stamp: 'Pending' },
    { step: 'onTheWay', stamp: 'Pending' },
    { step: 'arrived', stamp: 'Pending' },
    { step: 'verified', stamp: 'Pending' },
    { step: 'collected', stamp: 'Pending' },
    { step: 'completed', stamp: 'Pending' },
  ],

  quantityLabel: '25 boxes',
  surplusFacts: [
    { label: 'Food Category', value: 'Meal Boxes (Prepared Meals)' },
    { label: 'Availability Window', value: 'Today · 1:30 PM – 2:00 PM' },
    { label: 'Pickup Point', value: 'Main pickup counter (Service Door A)' },
    { label: 'Readiness Status', value: 'Ready for collection' },
  ],
  safetyNote:
    'Prepared today · kept covered · temperature safe (verified by Green ' +
    'Leaf manager at 1:16 PM)',

  partnerAddress: 'Downtown District · 412 Market St, Floor 1',
  partnerTier: 'Partner Tier: Gold Standard · Dispatch Bay 03',
  partnerVerified: true,
  operatorNote:
    'Partner on site, ready for direct handoff at entrance. Box units are ' +
    'pre-stacked in insulated thermal crates.',

  escalationTags: [
    { icon: 'notification_important', label: 'Rescue escalation active' },
    {
      icon: 'explore',
      label: 'Additional rescue coverage enabled (Tier-2 radius)',
    },
  ],
  escalationBody:
    'Automated match attempts running in expanded perimeter. 18 active ' +
    'couriers pinged.',

  privilegeLabel: 'Level 2 Privileges',
  actions: [
    { icon: 'cell_tower', label: 'Expand rescue coverage perimeter' },
    { icon: 'campaign', label: 'Contact rescue network coordinators' },
    { icon: 'verified', label: 'Mark for priority dispatch override' },
    {
      icon: 'cancel',
      label: 'Cancel rescue',
      caution: 'Requires supervisor override confirmation',
      destructive: true,
    },
  ],

  audit: [
    {
      title: 'Operator review required',
      time: '1:30 PM',
      detail:
        'Rescue reached 12 min threshold without confirmed courier. Alert ' +
        'sent to active operations deck.',
    },
    {
      title: 'Search expanded',
      time: '1:27 PM',
      detail:
        'Automated escalation enabled tier-2 courier perimeter (+2.5km ' +
        'expanded range).',
    },
    {
      title: 'No rescuer matched',
      time: '1:24 PM',
      detail:
        'Rescue escalation activated automatically after tier-1 couriers ' +
        'unresponsive or on active jobs.',
    },
    {
      title: 'Rescue search initiated',
      time: '1:20 PM',
      detail:
        'Alert broadcasted to 14 active nearby rescuers within immediate ' +
        'downtown zone.',
    },
    {
      title: 'Surplus published',
      time: '1:18 PM',
      detail:
        'Green Leaf Kitchen registered 25 meal boxes ready for immediate ' +
        'scheduled pickup.',
    },
  ],

  interventionTrigger: 'Escalation Trigger: Unmatched Surplus',
  interventionTriggerBody:
    'No rescuer matched within 18 minutes. Pickup window expires in 12 ' +
    'minutes.',
  interventionOptions: [
    {
      id: 'expand',
      title: 'Expand rescue coverage',
      description:
        'Broadcast high-priority push notification to tier-2 couriers and ' +
        'commercial logistics fleet in 3.5km perimeter.',
      footnote: 'Estimated courier arrival: 7–9 minutes',
      recommended: true,
    },
    {
      id: 'partner',
      title: 'Contact dedicated rescue partner',
      description:
        'Direct-assign job directly to Central Food Bank Rapid Courier Van ' +
        '#04 currently idling nearby.',
      footnote: 'Direct route distance: 1.1 km away',
    },
    {
      id: 'fallback',
      title: 'Zero-Waste fallback routing',
      description:
        'Reroute parcel status to Downtown Community Pantry walk-in rescue ' +
        'pool for immediate localized diversion.',
      footnote: 'Zero-waste diverted confirmation required',
    },
  ],
};
