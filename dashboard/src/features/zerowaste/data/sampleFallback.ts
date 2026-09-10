import type { FallbackOpportunity } from './fallbackTypes';

/**
 * Fixtures behind Fallback Opportunity, taken from the Stitch design
 * (`a75b3478a61043db95d66ff928a1c838`).
 *
 * **PHASE 14: delete this file.** The page takes a `FallbackOpportunity` prop.
 *
 * The copy, the four pathways, the three partners and the routing facts are
 * the mock's own. **One value is deliberately changed:** the mock names the
 * origin rescue `FL-20481`, which in this console is the rescue Amara Okonkwo
 * is currently carrying (see the Rescuers directory and Activity Log entry
 * `EV-90408`). A rescue cannot be both in progress and failed, so the origin
 * here is `FL-20470` - the dispatch that actually failed, per Activity Log
 * entry `EV-90390`. Everything an operator reads on the screen is otherwise
 * the design's.
 */
export const SAMPLE_FALLBACK_OPPORTUNITY: FallbackOpportunity = {
  id: 'FB-3081',
  originRescueId: 'FL-20470',

  tags: ['Rescue Unresolved', 'Alternative recovery recommended'],

  partner: 'Green Leaf Kitchen',
  surplusSummary: '25 meal boxes',
  issue: 'No community rescuer available within the active rescue window.',
  minutesRemaining: 12,

  inventory: {
    state: 'Ready for recovery',
    category: '25 meal boxes',
    categoryDetail: 'Prepared Meals - Ready for recovery',
    window: 'Today - 1:30 PM to 2:00 PM',
    windowDetail: 'Green Leaf Kitchen - Main pickup counter',
    handlingNote:
      'Prepared today - kept covered according to standard safety protocols.',
  },

  pathways: [
    {
      id: 'PW-FOOD',
      icon: 'handshake',
      name: 'Food Recovery Organization',
      state: 'recommended',
      statusLabel: 'Recommended',
      detail: 'Availability found - 2 active partners nearby',
      tier: 'human',
    },
    {
      id: 'PW-COMPOST',
      icon: 'compost',
      name: 'Composting / Organic Recovery',
      state: 'available',
      statusLabel: 'Available',
      detail: 'Availability found - Divert to soil nutrient',
      tier: 'composting',
    },
    {
      id: 'PW-BIOGAS',
      icon: 'bolt',
      name: 'Biogas / Anaerobic Digestion',
      state: 'limited',
      statusLabel: '1 Partner',
      detail: 'EcoDigest Facility available for energy conversion',
      tier: 'energy',
    },
    {
      id: 'PW-FEED',
      icon: 'pets',
      name: 'Animal-Feed Recovery',
      state: 'check',
      statusLabel: 'Check',
      detail: 'Requires strict heat-treatment verification',
      tier: 'animal_feed',
    },
  ],

  recommendedPathwayId: 'PW-FOOD',
  recommendationStatus: 'Recommended',
  recommendationAnalysis:
    'Suitable recovery partner available and pickup window remains active. 2 qualified organizations can fulfill the transfer before 2:00 PM. Estimated handover occurs within the active pickup window.',

  partners: [
    {
      id: 'RP-GC',
      mark: 'G',
      name: 'GreenCycle Recovery',
      kind: 'Food Recovery',
      pathwayId: 'PW-FOOD',
      etaMinutes: 12,
      available: true,
      destinationKind: 'Recovery Hub',
    },
    {
      id: 'RP-CH',
      mark: 'C',
      name: 'Community Harvest Hub',
      kind: 'Food Recovery',
      pathwayId: 'PW-FOOD',
      etaMinutes: 18,
      available: true,
      destinationKind: 'Community Kitchen',
    },
    {
      id: 'RP-ED',
      mark: 'E',
      name: 'EcoDigest Facility',
      kind: 'Biogas Recovery',
      pathwayId: 'PW-BIOGAS',
      etaMinutes: 22,
      available: true,
      destinationKind: 'Digestion Plant',
    },
  ],

  routing: {
    originName: 'Green Leaf Kitchen',
    originDetail: 'Pickup Counter',
    action: 'Direct Handover',
    pickupWindow: '1:30 - 2:00 PM',
    partnerStatus: 'Verified Active',
    handoverRequirement: 'Digital QR Scan',
  },

  activity: [
    { time: '1:31 PM', title: 'Fallback opportunity created', done: true },
    { time: '1:30 PM', title: 'Alternative recovery recommended', done: true },
    {
      time: '1:27 PM',
      title: 'Coverage expanded to secondary radius',
      done: false,
    },
    {
      time: '1:24 PM',
      title: 'No rescuer matched in initial window',
      done: false,
    },
    { time: '1:20 PM', title: 'Rescue search started', done: false },
  ],
};
