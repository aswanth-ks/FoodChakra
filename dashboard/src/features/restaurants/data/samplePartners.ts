import type { PartnerDirectory } from './partnerTypes';

/**
 * Fixtures behind the Restaurant Partners directory, from the Stitch design.
 *
 * **PHASE 14: delete this file.** The page takes a `PartnerDirectory` prop.
 * The table shows 6 of 248 because the design does; paging needs the API.
 */
export const SAMPLE_PARTNERS: PartnerDirectory = {
  totals: { all: 248, active: 231, attention: 11, inactive: 6 },

  locations: [
    'All Locations',
    'Downtown District',
    'Central District',
    'North Zone',
    'East District',
    'South Zone',
  ],

  rows: [
    {
      id: 'PT-1049',
      name: 'Green Leaf Kitchen',
      initials: 'GL',
      location: 'Downtown District',
      status: 'active',
      activeRescues: 2,
      completed: 184,
      lastActivity: '2 min ago',
    },
    {
      id: 'PT-1082',
      name: 'Sunrise Catering',
      initials: 'SC',
      location: 'Central District',
      status: 'active',
      activeRescues: 1,
      completed: 126,
      lastActivity: '8 min ago',
    },
    {
      id: 'PT-0921',
      name: 'Central Kitchen',
      initials: 'CK',
      location: 'North Zone',
      status: 'attention',
      activeRescues: 3,
      completed: 98,
      lastActivity: '14 min ago',
    },
    {
      id: 'PT-1153',
      name: 'Community Kitchen',
      initials: 'CK',
      location: 'East District',
      status: 'active',
      activeRescues: 1,
      completed: 211,
      lastActivity: '21 min ago',
    },
    {
      id: 'PT-0734',
      name: 'Harbor Point Bistro',
      initials: 'HP',
      location: 'South Zone',
      status: 'active',
      activeRescues: 0,
      completed: 62,
      lastActivity: '1 hour ago',
    },
    {
      id: 'PT-0612',
      name: 'Riverside Restaurant',
      initials: 'RR',
      location: 'South Zone',
      status: 'inactive',
      activeRescues: 0,
      completed: 74,
      lastActivity: '2 days ago',
    },
  ],

  page: 1,
  pageCount: 42,

  dossiers: {
    'PT-1049': {
      id: 'PT-1049',
      verified: true,
      branchLine: 'Downtown District · Main Branch',
      successRate: '96%',
      participation: 'High',
      pickupReadiness: 'Good (Punctual handovers)',
      incidents: 'None (0 in prior 30d)',
      healthLabel: 'Healthy Status',
      activity: [
        {
          when: '2 min ago',
          title: 'Rescuer matched',
          subject: 'Rescue #FL-20481 · 25 meal boxes',
          detail: 'Prepared meals · Handover scheduled 1:30 PM',
          rescueId: 'FL-20481',
        },
        {
          when: '18 min ago',
          title: 'Rescue completed',
          subject: 'Rescue #FL-20478 · 12 meal boxes',
          detail: 'Successfully verified by QR handshake',
        },
        {
          when: 'Today, 11:45 AM',
          title: 'Surplus published',
          subject: 'Rescue #FL-20470 · 18 meal portions',
          detail: 'Fresh bakery & prepared trays',
        },
      ],
    },
    'PT-0921': {
      id: 'PT-0921',
      verified: true,
      branchLine: 'North Zone · Dock #2',
      successRate: '88%',
      participation: 'High',
      pickupReadiness: 'Variable (2 late handovers)',
      incidents: '2 in prior 30d',
      healthLabel: 'Needs review',
      activity: [
        {
          when: '14 min ago',
          title: 'Rescuer cancelled',
          subject: 'Rescue #FL-20475 · 18 portions',
          detail: 'Re-dispatching to nearby couriers',
          rescueId: 'FL-20475',
        },
        {
          when: '1 hour ago',
          title: 'Surplus published',
          subject: 'Rescue #FL-20469 · 24 meal boxes',
          detail: 'Prepared meals · Cold chain held',
        },
      ],
    },
  },
};
