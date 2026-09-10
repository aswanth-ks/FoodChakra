import type { LocationDirectory } from './locationTypes';

/**
 * Fixtures behind Locations Management.
 *
 * **PHASE 14: delete this file.** The page takes a `LocationDirectory` prop.
 *
 * The zone names match the location filters used by the Restaurants and
 * Rescuers directories, so the three Management pages describe one network
 * rather than three unrelated ones.
 */
export const SAMPLE_LOCATIONS: LocationDirectory = {
  totals: { all: 6, live: 3, strained: 1, expanded: 1, paused: 1 },

  sectors: ['All Sectors', 'Sector 1', 'Sector 2', 'Sector 3'],

  rows: [
    {
      id: 'ZN-01',
      name: 'Downtown District',
      sector: 'Sector 1',
      status: 'live',
      partners: 62,
      rescuers: 94,
      activeRescues: 14,
      standardRadius: '2.5 km',
      currentRadius: '2.5 km',
      coverage: '96.8%',
      avgDispatch: '3.8 min',
    },
    {
      id: 'ZN-02',
      name: 'Central District',
      sector: 'Sector 1',
      status: 'live',
      partners: 48,
      rescuers: 71,
      activeRescues: 9,
      standardRadius: '2.5 km',
      currentRadius: '2.5 km',
      coverage: '95.1%',
      avgDispatch: '4.1 min',
    },
    {
      id: 'ZN-03',
      name: 'North Zone',
      sector: 'Sector 2',
      status: 'expanded',
      partners: 39,
      rescuers: 44,
      activeRescues: 11,
      standardRadius: '3.0 km',
      currentRadius: '5.5 km',
      coverage: '88.4%',
      avgDispatch: '7.6 min',
    },
    {
      id: 'ZN-04',
      name: 'East District',
      sector: 'Sector 2',
      status: 'strained',
      partners: 51,
      rescuers: 28,
      activeRescues: 8,
      standardRadius: '3.0 km',
      currentRadius: '3.0 km',
      coverage: '79.2%',
      avgDispatch: '11.3 min',
    },
    {
      id: 'ZN-05',
      name: 'South Zone',
      sector: 'Sector 3',
      status: 'live',
      partners: 42,
      rescuers: 63,
      activeRescues: 0,
      standardRadius: '3.5 km',
      currentRadius: '3.5 km',
      coverage: '93.7%',
      avgDispatch: '5.2 min',
    },
    {
      id: 'ZN-06',
      name: 'Harbour Fringe',
      sector: 'Sector 3',
      status: 'paused',
      partners: 6,
      rescuers: 3,
      activeRescues: 0,
      standardRadius: '4.0 km',
      currentRadius: 'None',
      coverage: '0%',
      avgDispatch: 'n/a',
    },
  ],

  details: {
    'ZN-01': {
      id: 'ZN-01',
      summary:
        'Operating normally. Rescuer supply comfortably ahead of surplus volume through the evening peak.',
      population: '184,000 served',
      area: '12.6 km2',
      peakWindow: '18:00 - 21:00',
      unmatchedRate: '1.2% of rescues',
      pickupPoints: [
        {
          name: 'Downtown Shelter',
          kind: 'Distribution partner',
          hours: 'Open 07:00-23:00',
          active: true,
        },
        {
          name: 'Riverside Community Hall',
          kind: 'Distribution partner',
          hours: 'Open 09:00-19:00',
          active: true,
        },
        {
          name: 'Market Street Hub',
          kind: 'Consolidation point',
          hours: 'Open 06:00-22:00',
          active: true,
        },
      ],
      events: [
        {
          when: '2 h ago',
          title: 'Peak staffing reached',
          detail: '94 rescuers on shift, 12 above the evening target.',
        },
        {
          when: 'Yesterday',
          title: 'Partner onboarded',
          detail: 'Green Leaf Kitchen activated in this zone.',
        },
      ],
    },
    'ZN-02': {
      id: 'ZN-02',
      summary:
        'Operating normally. Dispatch times steady across the trailing 24 hours.',
      population: '141,000 served',
      area: '10.9 km2',
      peakWindow: '17:30 - 20:30',
      unmatchedRate: '2.0% of rescues',
      pickupPoints: [
        {
          name: 'Central Food Bank',
          kind: 'Distribution partner',
          hours: 'Open 08:00-20:00',
          active: true,
        },
        {
          name: 'St. Anne Parish Kitchen',
          kind: 'Distribution partner',
          hours: 'Open 11:00-18:00',
          active: true,
        },
      ],
      events: [
        {
          when: '6 h ago',
          title: 'Coverage band reviewed',
          detail: 'Standard radius held at 2.5 km; no change required.',
        },
      ],
    },
    'ZN-03': {
      id: 'ZN-03',
      summary:
        'Coverage is currently expanded to 5.5 km. Dynamic coverage widened the band after four rescues went unmatched inside the standard radius during the evening peak.',
      population: '97,000 served',
      area: '21.4 km2',
      peakWindow: '18:00 - 22:00',
      unmatchedRate: '9.4% of rescues',
      pickupPoints: [
        {
          name: 'North Community Centre',
          kind: 'Distribution partner',
          hours: 'Open 09:00-21:00',
          active: true,
        },
        {
          name: 'Hillside Depot',
          kind: 'Consolidation point',
          hours: 'Open 06:00-14:00',
          active: false,
        },
      ],
      events: [
        {
          when: '38 min ago',
          title: 'Coverage expanded',
          detail: 'Radius widened 3.0 km to 5.5 km by smart escalation.',
        },
        {
          when: '52 min ago',
          title: 'Unmatched threshold crossed',
          detail: 'Four rescues unmatched inside the standard band.',
        },
        {
          when: '4 h ago',
          title: 'Rescuer supply dipped',
          detail: '44 on shift against a 60 target for the evening peak.',
        },
      ],
    },
    'ZN-04': {
      id: 'ZN-04',
      summary:
        'Strained. 51 partners are publishing surplus against only 28 rescuers, and dispatch time is more than double the network average.',
      population: '166,000 served',
      area: '18.4 km2',
      peakWindow: '18:00 - 21:00',
      unmatchedRate: '14.6% of rescues',
      pickupPoints: [
        {
          name: 'Eastgate Shelter',
          kind: 'Distribution partner',
          hours: 'Open 07:00-22:00',
          active: true,
        },
        {
          name: 'Fairview Kitchen',
          kind: 'Distribution partner',
          hours: 'Open 10:00-16:00',
          active: true,
        },
      ],
      events: [
        {
          when: '25 min ago',
          title: 'Strain flagged',
          detail: 'Partner-to-rescuer ratio crossed the 1.6 threshold.',
        },
        {
          when: '3 h ago',
          title: 'Recruitment prompt queued',
          detail: 'Zone added to the rescuer recruitment shortlist.',
        },
      ],
    },
    'ZN-05': {
      id: 'ZN-05',
      summary:
        'Operating normally, currently outside its surplus window. Next peak begins at 17:00.',
      population: '128,000 served',
      area: '24.1 km2',
      peakWindow: '17:00 - 20:00',
      unmatchedRate: '3.1% of rescues',
      pickupPoints: [
        {
          name: 'South Community Kitchen',
          kind: 'Distribution partner',
          hours: 'Open 08:00-20:00',
          active: true,
        },
      ],
      events: [
        {
          when: '5 h ago',
          title: 'Window closed',
          detail: 'All 7 rescues in the midday window completed.',
        },
      ],
    },
    'ZN-06': {
      id: 'ZN-06',
      summary:
        'Paused by operator. The zone was opened for a pilot and never reached the partner density needed to dispatch reliably.',
      population: '19,000 served',
      area: '31.8 km2',
      peakWindow: 'None scheduled',
      unmatchedRate: 'n/a - no dispatch',
      pickupPoints: [
        {
          name: 'Harbour Mission',
          kind: 'Distribution partner',
          hours: 'Closed',
          active: false,
        },
      ],
      events: [
        {
          when: '11 days ago',
          title: 'Zone paused',
          detail: 'Operator action - pilot ended below partner density target.',
        },
      ],
    },
  },
};
