import type {
  RecoveryPartnerDirectory,
  RoutingPolicy,
  ZeroWasteOverview,
} from './zeroWasteTypes';

/**
 * Fixtures behind the Zero-Waste Network console.
 *
 * **PHASE 14: delete this file.** Each page takes its data as a prop, so only
 * the source changes when the console API exists.
 *
 * Continuity with the rest of the console is deliberate: `FB-3081` is the
 * fallback case opened by rescue `FL-20470`, whose failed dispatch is the
 * `EV-90390` entry in the Activity Log, and the zones match Locations. The
 * tier that a case can still reach is driven by condition and time, not by
 * preference - that is the point of the hierarchy.
 */

export const SAMPLE_ZERO_WASTE_OVERVIEW: ZeroWasteOverview = {
  window: 'Trailing 7 days',

  totals: {
    divertedKg: 4820,
    diversionRate: 91.4,
    openCases: 5,
    activePartners: 14,
    landfillKg: 452,
    co2Avoided: '11.6 t CO2e',
  },

  hierarchy: [
    { tier: 'human', kg: 18240, share: 77.2, consignments: 612 },
    { tier: 'animal_feed', kg: 2960, share: 12.5, consignments: 84 },
    { tier: 'composting', kg: 1420, share: 6.0, consignments: 51 },
    { tier: 'energy', kg: 440, share: 1.9, consignments: 12 },
    { tier: 'landfill', kg: 452, share: 1.9, consignments: 9 },
  ],

  cases: [
    {
      id: 'FB-3081',
      rescueId: 'FL-20470',
      surplus: '25 meal boxes',
      kg: 46,
      partner: 'Green Leaf Kitchen',
      zone: 'Downtown District',
      reason: 'No community rescuer available within the active rescue window.',
      minutesLeft: 12,
      proposedTier: 'human',
      severity: 'critical',
    },
    {
      id: 'FB-3079',
      rescueId: 'FL-20461',
      surplus: '12 crates mixed produce',
      kg: 84,
      partner: 'Central Kitchen',
      zone: 'North Zone',
      reason: 'Cold chain broken during handover; unfit for people.',
      minutesLeft: 145,
      proposedTier: 'animal_feed',
      severity: 'attention',
    },
    {
      id: 'FB-3076',
      rescueId: 'FL-20448',
      surplus: 'Bakery surplus, 9 trays',
      kg: 22,
      partner: 'Sunrise Catering',
      zone: 'Central District',
      reason: 'Past the safe consumption window on arrival.',
      minutesLeft: 320,
      proposedTier: 'animal_feed',
      severity: 'steady',
    },
    {
      id: 'FB-3074',
      rescueId: 'FL-20440',
      surplus: 'Vegetable trim and peelings',
      kg: 138,
      partner: 'Community Kitchen',
      zone: 'East District',
      reason: 'Preparation waste; never eligible for the human tier.',
      minutesLeft: 610,
      proposedTier: 'composting',
      severity: 'steady',
    },
    {
      id: 'FB-3071',
      rescueId: 'FL-20422',
      surplus: 'Spoiled dairy, 30 units',
      kg: 41,
      partner: 'Eastgate Market',
      zone: 'East District',
      reason: 'Spoiled on arrival; not recoverable as feed.',
      minutesLeft: 95,
      proposedTier: 'energy',
      severity: 'attention',
    },
  ],

  events: [
    {
      when: '12 min ago',
      title: 'Diverted to animal feed',
      detail: 'FB-3068 collected by Meadowbrook Farm from Central District.',
      tier: 'animal_feed',
      kg: 62,
    },
    {
      when: '48 min ago',
      title: 'Diverted to composting',
      detail: 'FB-3064 collected by Riverbend Composting from South Zone.',
      tier: 'composting',
      kg: 118,
    },
    {
      when: '2 h ago',
      title: 'Sent to energy recovery',
      detail: 'FB-3059 accepted by Northgate Biogas after feed was refused.',
      tier: 'energy',
      kg: 37,
    },
    {
      when: '3 h ago',
      title: 'Landfill - no tier reachable',
      detail:
        'FB-3055 exceeded every recovery window before a partner could collect.',
      tier: 'landfill',
      kg: 24,
    },
    {
      when: '5 h ago',
      title: 'Diverted to animal feed',
      detail: 'FB-3051 collected by Hillcrest Piggery from North Zone.',
      tier: 'animal_feed',
      kg: 91,
    },
  ],
};

/**
 * The case an operator should be looking at first: the least time left.
 *
 * The sidebar's Fallback Opportunity entry needs a concrete destination, and
 * "the most urgent open case" is the honest one - the same case the overview
 * puts at the top of its queue. Phase 14 resolves this server-side; until then
 * it is derived from the fixture rather than hard-coded, so the two pages
 * cannot disagree about which case is most urgent.
 */
export function mostUrgentCaseId(
  overview: ZeroWasteOverview = SAMPLE_ZERO_WASTE_OVERVIEW,
): string | null {
  const open = [...overview.cases].sort(
    (a, b) => a.minutesLeft - b.minutesLeft,
  );
  return open[0]?.id ?? null;
}

export const SAMPLE_RECOVERY_PARTNERS: RecoveryPartnerDirectory = {
  totals: { all: 18, accepting: 14, atCapacity: 3, offline: 1 },

  zones: [
    'All Zones',
    'Downtown District',
    'Central District',
    'North Zone',
    'East District',
    'South Zone',
  ],

  rows: [
    {
      id: 'RP-204',
      name: 'Meadowbrook Farm',
      initials: 'MF',
      tier: 'animal_feed',
      zone: 'North Zone',
      status: 'accepting',
      capacityKg: 400,
      usedKg: 220,
      accepts: ['Prepared food', 'Bakery', 'Produce'],
      hours: 'Open 06:00-18:00',
      lifetimeKg: 8420,
    },
    {
      id: 'RP-211',
      name: 'Hillcrest Piggery',
      initials: 'HP',
      tier: 'animal_feed',
      zone: 'North Zone',
      status: 'at_capacity',
      capacityKg: 260,
      usedKg: 248,
      accepts: ['Prepared food', 'Produce'],
      hours: 'Open 07:00-16:00',
      lifetimeKg: 5140,
    },
    {
      id: 'RP-118',
      name: 'Riverbend Composting',
      initials: 'RC',
      tier: 'composting',
      zone: 'South Zone',
      status: 'accepting',
      capacityKg: 3000,
      usedKg: 600,
      accepts: ['Produce', 'Preparation waste', 'Bakery', 'Dairy'],
      hours: 'Open 05:00-21:00',
      lifetimeKg: 41200,
    },
    {
      id: 'RP-127',
      name: 'Eastfield Compost Yard',
      initials: 'EC',
      tier: 'composting',
      zone: 'East District',
      status: 'accepting',
      capacityKg: 1800,
      usedKg: 1310,
      accepts: ['Produce', 'Preparation waste'],
      hours: 'Open 06:00-20:00',
      lifetimeKg: 22600,
    },
    {
      id: 'RP-302',
      name: 'Northgate Biogas',
      initials: 'NB',
      tier: 'energy',
      zone: 'North Zone',
      status: 'accepting',
      capacityKg: 12000,
      usedKg: 3400,
      accepts: ['Prepared food', 'Dairy', 'Produce', 'Preparation waste'],
      hours: 'Open 24 hours',
      lifetimeKg: 96400,
    },
    {
      id: 'RP-309',
      name: 'Harbour Digestion Plant',
      initials: 'HD',
      tier: 'energy',
      zone: 'Downtown District',
      status: 'offline',
      capacityKg: 8000,
      usedKg: 0,
      accepts: ['Prepared food', 'Dairy'],
      hours: 'Closed for maintenance',
      lifetimeKg: 51800,
    },
  ],

  details: {
    'RP-204': {
      id: 'RP-204',
      licence: 'ABP Cat. 3 permit - FL-ABP-2291',
      contact: 'ops@meadowbrook.example - +44 20 7946 0121',
      turnaround: 'Processed within 12 h of collection',
      excludes: ['Dairy', 'Meat off the bone'],
      note: 'Preferred animal-feed destination for North Zone: closest tier-2 partner with reliable same-day collection.',
      activity: [
        {
          when: '12 min ago',
          title: 'Collected FB-3068',
          detail: 'Central District, prepared food.',
          kg: 62,
        },
        {
          when: '5 h ago',
          title: 'Collected FB-3051',
          detail: 'North Zone, bakery surplus.',
          kg: 91,
        },
      ],
    },
    'RP-211': {
      id: 'RP-211',
      licence: 'ABP Cat. 3 permit - FL-ABP-2318',
      contact: 'yard@hillcrest.example - +44 20 7946 0188',
      turnaround: 'Processed within 24 h of collection',
      excludes: ['Dairy', 'Packaged goods'],
      note: 'At capacity for today. Intake reopens at 07:00 tomorrow.',
      activity: [
        {
          when: '2 h ago',
          title: 'Reached daily ceiling',
          detail: '248 kg of a 260 kg ceiling taken.',
          kg: 248,
        },
      ],
    },
    'RP-118': {
      id: 'RP-118',
      licence: 'Composting permit - FL-CMP-0442',
      contact: 'intake@riverbend.example - +44 20 7946 0204',
      turnaround: 'Windrow within 48 h',
      excludes: ['Packaging', 'Meat'],
      note: 'Highest-capacity composting partner and the routing fallback for South Zone produce.',
      activity: [
        {
          when: '48 min ago',
          title: 'Collected FB-3064',
          detail: 'South Zone, mixed produce.',
          kg: 118,
        },
      ],
    },
    'RP-127': {
      id: 'RP-127',
      licence: 'Composting permit - FL-CMP-0517',
      contact: 'yard@eastfield.example - +44 20 7946 0233',
      turnaround: 'Windrow within 72 h',
      excludes: ['Packaging', 'Meat', 'Dairy'],
      note: 'Approaching its daily ceiling; routing deprioritises it past 1,500 kg.',
      activity: [
        {
          when: '3 h ago',
          title: 'Collected FB-3062',
          detail: 'East District, preparation waste.',
          kg: 210,
        },
      ],
    },
    'RP-302': {
      id: 'RP-302',
      licence: 'Anaerobic digestion permit - FL-AD-0091',
      contact: 'control@northgate.example - +44 20 7946 0310',
      turnaround: 'Into digester within 6 h',
      excludes: ['Packaging'],
      note: 'Last recoverable tier before landfill. Effectively unrestricted capacity, so routing must never reach it before feed and composting are exhausted.',
      activity: [
        {
          when: '2 h ago',
          title: 'Accepted FB-3059',
          detail: 'North Zone, after animal feed refused the load.',
          kg: 37,
        },
      ],
    },
    'RP-309': {
      id: 'RP-309',
      licence: 'Anaerobic digestion permit - FL-AD-0104',
      contact: 'control@harbourdigestion.example - +44 20 7946 0355',
      turnaround: 'Into digester within 8 h',
      excludes: ['Packaging'],
      note: 'Offline for scheduled maintenance. Downtown energy-recovery volume is routing to Northgate meanwhile, at a longer haul.',
      activity: [
        {
          when: '4 days ago',
          title: 'Taken offline',
          detail: 'Scheduled digester maintenance, 6 days.',
          kg: 0,
        },
      ],
    },
  },
};

export const SAMPLE_ROUTING_POLICY: RoutingPolicy = {
  window: 'Trailing 7 days',
  autoRoutedShare: 86.3,
  manualCount: 21,
  unplacedCount: 9,

  rules: [
    {
      id: 'RL-01',
      priority: 1,
      name: 'Retry human tier while fit',
      condition:
        'Surplus still within its safe consumption window and cold chain intact',
      destination: 'human',
      enabled: true,
      matches: 34,
      rationale:
        'A case reaching the fallback tier is not automatically unfit. Feeding people is the top of the hierarchy and must be retried before anything else.',
    },
    {
      id: 'RL-02',
      priority: 2,
      name: 'Cooked food to animal feed',
      condition:
        'Category is prepared or bakery, no dairy or meat, ABP-permitted partner reachable in window',
      destination: 'animal_feed',
      enabled: true,
      matches: 84,
      rationale:
        'Animal feed is the highest recovery tier for cooked surplus, and the permit condition is a legal requirement, not a preference.',
    },
    {
      id: 'RL-03',
      priority: 3,
      name: 'Produce and prep waste to composting',
      condition: 'Category is produce or preparation waste, or feed refused',
      destination: 'composting',
      enabled: true,
      matches: 51,
      rationale:
        'Preparation waste is never eligible for the tiers above, so it routes straight here.',
    },
    {
      id: 'RL-04',
      priority: 4,
      name: 'Spoiled or mixed loads to energy recovery',
      condition: 'Spoiled on arrival, or contaminated, or no tier above matched',
      destination: 'energy',
      enabled: true,
      matches: 12,
      rationale:
        'Last recoverable tier. Capacity here is effectively unrestricted, which is exactly why it must sit last - an earlier position would quietly drain volume away from feed and composting.',
    },
    {
      id: 'RL-05',
      priority: 5,
      name: 'Landfill of last resort',
      condition: 'No recovery partner reachable before the window closes',
      destination: 'landfill',
      enabled: true,
      matches: 9,
      rationale:
        'Not a routing choice so much as the absence of one. Every match here is a failure worth reviewing.',
    },
  ],

  preview: [
    {
      caseId: 'FB-3081',
      surplus: '18 prepared meal trays',
      kg: 46,
      category: 'Prepared food, cooked',
      ruleId: 'RL-02',
      destination: 'animal_feed',
      partner: 'Meadowbrook Farm',
      placed: true,
    },
    {
      caseId: 'FB-3079',
      surplus: '12 crates mixed produce',
      kg: 84,
      category: 'Produce',
      ruleId: 'RL-02',
      destination: 'animal_feed',
      partner: 'Meadowbrook Farm',
      placed: true,
    },
    {
      caseId: 'FB-3076',
      surplus: 'Bakery surplus, 9 trays',
      kg: 22,
      category: 'Bakery',
      ruleId: 'RL-02',
      destination: 'animal_feed',
      partner: 'Hillcrest Piggery',
      placed: true,
    },
    {
      caseId: 'FB-3074',
      surplus: 'Vegetable trim and peelings',
      kg: 138,
      category: 'Preparation waste',
      ruleId: 'RL-03',
      destination: 'composting',
      partner: 'Eastfield Compost Yard',
      placed: true,
    },
    {
      caseId: 'FB-3071',
      surplus: 'Spoiled dairy, 30 units',
      kg: 41,
      category: 'Dairy, spoiled',
      ruleId: 'RL-04',
      destination: 'energy',
      partner: 'Northgate Biogas',
      placed: true,
    },
    {
      caseId: 'FB-3066',
      surplus: 'Packaged ready meals',
      kg: 58,
      category: 'Packaged, mixed',
      ruleId: 'RL-05',
      destination: 'landfill',
      partner: 'No partner reachable',
      placed: false,
    },
  ],
};
