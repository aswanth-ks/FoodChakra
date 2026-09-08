import type { CoverageData } from './coverageTypes';

/**
 * Fixture data behind the Dynamic Rescue Coverage page, from the Stitch
 * design.
 *
 * **PHASE 14: delete this file.** The page takes a `CoverageData` prop.
 */
export const SAMPLE_COVERAGE: CoverageData = {
  zone: 'Dispatch Zone Sector 4',
  bannerTitle: 'ADAPTIVE COVERAGE ACTIVE',
  bannerBody:
    'FoodLoop automatically adjusts rescue coverage when normal matching ' +
    'does not produce a suitable rescuer.',

  activeRescues: 42,
  expandedCount: 7,
  reviewRequired: 3,

  sites: [
    {
      id: 'green-leaf',
      label: 'Green Leaf Kitchen',
      detail: '(25 boxes)',
      x: 430,
      y: 260,
      focus: true,
    },
    { id: 'sunrise', label: 'Sunrise Catering', x: 165, y: 130 },
    { id: 'community', label: 'Community Food Center', x: 690, y: 150 },
    { id: 'riverside', label: 'Riverside Restaurant', x: 720, y: 400 },
  ],

  responders: [
    {
      id: 'r-104',
      label: 'Courier #104',
      mode: 'van',
      caption: 'Courier #104 · Van · 4 min away',
      x: 300,
      y: 175,
    },
    {
      id: 'r-sam',
      label: 'Volunteer Sam',
      mode: 'bike',
      caption: 'Volunteer Sam · Cargo Bike · En Route',
      x: 560,
      y: 190,
    },
    {
      id: 'r-dan',
      label: 'Rescuer Dan',
      mode: 'foot',
      caption: 'Rescuer Dan · Finishing drop-off',
      x: 330,
      y: 380,
    },
  ],

  rings: [
    { level: 'standard', radius: 90 },
    { level: 'expanded', radius: 150 },
    { level: 'extended', radius: 215 },
  ],

  trigger: 'Trigger: Automated dispatch threshold',
  factors: [
    {
      icon: 'group',
      title: 'Rescuer Availability',
      finding: 'Limited nearby availability',
      metricLabel: 'Zone density',
      metricValue: 'Low (22%)',
    },
    {
      icon: 'schedule',
      title: 'Pickup Urgency',
      finding: 'Pickup window approaching',
      metricLabel: 'Remaining',
      metricValue: '12 minutes',
    },
    {
      icon: 'trending_up',
      title: 'Rescue Demand',
      finding: 'Additional coverage recommended',
      metricLabel: 'Match probability',
      metricValue: 'High with expanded',
    },
  ],

  events: [
    {
      time: '1:20 PM',
      title: 'Standard rescue search started',
      detail: 'Radius: 1.5 km · 4 courier notifications dispatched',
    },
    {
      time: '1:24 PM',
      title: 'No suitable rescuer found',
      detail: 'Initial timeout threshold reached without responder match',
    },
    {
      time: '1:24 PM',
      title: 'Coverage expanded',
      detail: 'Perimeter expanded to Zone 2 (+2.0 km radius)',
    },
    {
      time: '1:27 PM',
      title: 'Additional rescue coverage activated',
      detail:
        'Broadcasting to secondary courier pools and backup cargo cyclists',
    },
    {
      time: '1:30 PM',
      title: 'Operator review recommended',
      detail: 'Window expiration approaching within 15 min threshold',
    },
  ],

  partner: 'Green Leaf Kitchen',
  severityLabel: 'CRITICAL',
  quantityLine: '25 meal boxes · Prepared surplus',
  handlingNote:
    'Commercial chilled prepared meals, requires insulated transport bag.',
  currentState: 'No rescuer matched',
  minutesRemaining: 12,
  pickupWindow: 'Today · 1:30 PM – 2:00 PM',

  currentLevel: 'expanded',
  levelExplanation:
    'No suitable rescuer was found in standard coverage. Additional rescue ' +
    'coverage is now active.',

  stats: [
    { label: 'Active rescue coverage', value: '42 rescues', icon: 'inventory' },
    { label: 'Expanded coverage', value: '7 active', icon: 'wifi_tethering' },
    { label: 'Extended coverage', value: '2 active', icon: 'hub' },
  ],
};
