import type { RescuerDirectory } from './rescuerTypes';

/**
 * Fixtures behind Rescuers Management.
 *
 * **PHASE 14: delete this file.** The page takes a `RescuerDirectory` prop, so
 * only the source changes when the console API exists.
 *
 * The counts are kept consistent with `SAMPLE_NETWORK_STATUS` (38 rescuers
 * online, 42 active rescues) so the status strip and this page do not
 * contradict each other while both are fixture-driven.
 */
export const SAMPLE_RESCUERS: RescuerDirectory = {
  totals: { all: 412, onRescue: 24, available: 14, offline: 368, suspended: 6 },

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
      id: 'RS-4821',
      name: 'Amara Okonkwo',
      initials: 'AO',
      zone: 'Downtown District',
      status: 'on_rescue',
      verification: 'verified',
      currentRescueId: 'FL-20481',
      completed: 312,
      reliability: '98.4%',
      lastSeen: 'Live now',
    },
    {
      id: 'RS-4102',
      name: 'Daniel Ferreira',
      initials: 'DF',
      zone: 'Central District',
      status: 'on_rescue',
      verification: 'verified',
      currentRescueId: 'FL-20477',
      completed: 189,
      reliability: '96.1%',
      lastSeen: 'Live now',
    },
    {
      id: 'RS-5310',
      name: 'Priya Raghunathan',
      initials: 'PR',
      zone: 'North Zone',
      status: 'available',
      verification: 'verified',
      completed: 274,
      reliability: '97.8%',
      lastSeen: '3 min ago',
    },
    {
      id: 'RS-4967',
      name: 'Tomas Herrera',
      initials: 'TH',
      zone: 'East District',
      status: 'available',
      verification: 'pending',
      completed: 41,
      reliability: '92.3%',
      lastSeen: '11 min ago',
    },
    {
      id: 'RS-3844',
      name: 'Sofia Lindqvist',
      initials: 'SL',
      zone: 'South Zone',
      status: 'offline',
      verification: 'verified',
      completed: 508,
      reliability: '99.1%',
      lastSeen: '4 h ago',
    },
    {
      id: 'RS-5122',
      name: 'Marcus Bell',
      initials: 'MB',
      zone: 'Downtown District',
      status: 'suspended',
      verification: 'expired',
      completed: 63,
      reliability: '71.2%',
      lastSeen: '2 days ago',
    },
  ],

  page: 1,
  pageCount: 69,

  dossiers: {
    'RS-4821': {
      id: 'RS-4821',
      joined: 'Joined Mar 2025',
      transport: 'Cargo bicycle - 18 kg capacity',
      avgPickupTime: '11 min',
      acceptanceRate: '94%',
      cancellations: '2 in trailing 90 days',
      distance: '412 km in trailing 30 days',
      standing: 'Good standing - no operator flags.',
      activity: [
        {
          when: '4 min ago',
          title: 'Rescue accepted',
          subject: 'Rescue #FL-20481 - 25 meal boxes',
          detail: 'Green Leaf Kitchen to Downtown Shelter',
          rescueId: 'FL-20481',
        },
        {
          when: '52 min ago',
          title: 'Handover verified',
          subject: 'Rescue #FL-20463 - 12 produce crates',
          detail: 'Completed 6 min inside the pickup window.',
          rescueId: 'FL-20463',
        },
        {
          when: '2 h ago',
          title: 'Shift started',
          subject: 'Downtown District',
          detail: 'Availability set from the mobile app.',
        },
      ],
    },
    'RS-4102': {
      id: 'RS-4102',
      joined: 'Joined Nov 2025',
      transport: 'Scooter - 40 kg capacity',
      avgPickupTime: '14 min',
      acceptanceRate: '88%',
      cancellations: '5 in trailing 90 days',
      distance: '806 km in trailing 30 days',
      standing: 'Good standing - no operator flags.',
      activity: [
        {
          when: '18 min ago',
          title: 'Rescue accepted',
          subject: 'Rescue #FL-20477 - 8 bread trays',
          detail: 'Sunrise Catering to Central Food Bank',
          rescueId: 'FL-20477',
        },
        {
          when: '3 h ago',
          title: 'Handover verified',
          subject: 'Rescue #FL-20402 - 30 meal boxes',
          detail: 'Completed at the window edge.',
          rescueId: 'FL-20402',
        },
      ],
    },
    'RS-5310': {
      id: 'RS-5310',
      joined: 'Joined Jun 2025',
      transport: 'Car - 90 kg capacity',
      avgPickupTime: '9 min',
      acceptanceRate: '96%',
      cancellations: '1 in trailing 90 days',
      distance: '1,204 km in trailing 30 days',
      standing: 'Good standing - top decile reliability in North Zone.',
      activity: [
        {
          when: '3 min ago',
          title: 'Went available',
          subject: 'North Zone',
          detail: 'Waiting on a dispatch match.',
        },
        {
          when: '41 min ago',
          title: 'Handover verified',
          subject: 'Rescue #FL-20455 - 20 meal boxes',
          detail: 'Completed 14 min inside the pickup window.',
          rescueId: 'FL-20455',
        },
      ],
    },
    'RS-4967': {
      id: 'RS-4967',
      joined: 'Joined Aug 2026',
      transport: 'Bicycle - 12 kg capacity',
      avgPickupTime: '17 min',
      acceptanceRate: '79%',
      cancellations: '4 in trailing 90 days',
      distance: '96 km in trailing 30 days',
      standing:
        'Identity documents submitted 3 days ago and still awaiting review.',
      activity: [
        {
          when: '11 min ago',
          title: 'Went available',
          subject: 'East District',
          detail: 'Limited to low-value rescues until verification clears.',
        },
        {
          when: '3 days ago',
          title: 'Verification submitted',
          subject: 'Identity documents',
          detail: 'Queued for operator review.',
        },
      ],
    },
    'RS-3844': {
      id: 'RS-3844',
      joined: 'Joined Jan 2025',
      transport: 'Cargo bicycle - 18 kg capacity',
      avgPickupTime: '10 min',
      acceptanceRate: '91%',
      cancellations: '3 in trailing 90 days',
      distance: '288 km in trailing 30 days',
      standing: 'Good standing - highest lifetime completions in South Zone.',
      activity: [
        {
          when: '4 h ago',
          title: 'Shift ended',
          subject: 'South Zone',
          detail: 'Three rescues completed on shift.',
        },
      ],
    },
    'RS-5122': {
      id: 'RS-5122',
      joined: 'Joined Feb 2026',
      transport: 'Scooter - 40 kg capacity',
      avgPickupTime: '23 min',
      acceptanceRate: '62%',
      cancellations: '19 in trailing 90 days',
      distance: '54 km in trailing 30 days',
      standing:
        'Suspended by operator after three consecutive no-shows on accepted rescues.',
      activity: [
        {
          when: '2 days ago',
          title: 'Account suspended',
          subject: 'Operator action - ops-desk-2',
          detail: 'Third no-show on an accepted rescue within 14 days.',
        },
        {
          when: '2 days ago',
          title: 'Rescue reassigned',
          subject: 'Rescue #FL-20330 - 16 meal boxes',
          detail: 'Escalated to expanded coverage after the no-show.',
          rescueId: 'FL-20330',
        },
      ],
    },
  },
};
