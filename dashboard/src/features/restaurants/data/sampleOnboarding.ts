import type { OnboardingConfig } from './onboardingTypes';

/**
 * Static copy and options for the onboarding wizard, from the Stitch designs.
 *
 * **PHASE 14: the entity id and hub become server-assigned.** The capability
 * list and role scoping must come from the backend's own role definitions,
 * not from the client, so the console cannot claim a scope the server would
 * not actually grant.
 */
export const ONBOARDING_CONFIG: OnboardingConfig = {
  entityId: 'FL-ENT-88429',
  dispatchHub: 'Central Metro District',
  operatorDesk: 'Operator Desk #02',
  operatorName: 'Alex Sterling',

  baseline: [
    {
      label: 'Partner Type',
      value: 'Restaurant Partner',
      caption: 'Standard Commercial',
      icon: 'storefront',
    },
    {
      label: 'Rescue Participation',
      value: 'Active Pipeline',
      caption: 'Enabled by Default',
      icon: 'bolt',
    },
    {
      label: 'Pickup Method',
      value: 'Direct Kitchen Handover',
      caption: 'Standard route',
      icon: 'swap_horiz',
    },
    {
      label: 'Safety Standard Tier',
      value: 'Cold/Warm Chain Standard',
      caption: 'Holding compliance',
      icon: 'ac_unit',
    },
  ],
  baselineNote:
    'Partner automatically binds to FoodLoop Cold/Warm Chain Holding ' +
    'Standards upon provisioning dispatch.',

  roleTitle: 'Restaurant Partner (Standard Tier)',
  roleCaption: 'Standard restaurant dashboard access & surplus dispatcher',
  roleConsole: 'Console: Partner Portal',
  capabilities: [
    'Publish and update surplus food rescue batches',
    'Confirm volunteer courier handshakes & digital QR signatures',
    'Monitor live volunteer arrivals in real-time',
    'View monthly diverted kg, meals rescued & CO2e offset',
  ],
  roleNote:
    'Administrator and billing oversight roles cannot be provisioned through ' +
    'desk operator onboarding; elevated scopes require Security Officer ' +
    'review.',

  zeroPasswordTitle: 'Zero-Password Operator Architecture',
  zeroPasswordLead:
    'Operators never view, assign, or handle partner passwords',
  zeroPasswordBody:
    'FoodLoop desk operators never generate temporary passwords. An ' +
    'encrypted, single-use activation token is prepared and will be ' +
    'dispatched directly to the partner at Step 3. The restaurant manager ' +
    'configures their own multi-factor credentials during their initial ' +
    'onboarding browser session.',

  lifecycle: [
    {
      index: 1,
      tag: 'Current',
      title: 'Access Profile Staged',
      body: 'Desk operator assigns target email, role bounds, and branch linkage.',
    },
    {
      index: 2,
      tag: 'Step 3',
      title: 'Invitation Dispatched',
      body: 'Signed TLS email sent with cryptographic HMAC-256 activation token.',
    },
    {
      index: 3,
      tag: 'Partner Side',
      title: 'Credentials Created',
      body: 'Partner establishes secure password, 2FA authenticator, and PIN.',
    },
    {
      index: 4,
      tag: 'Complete',
      title: 'Active Rescue Access',
      body: 'Full dashboard unlocked for real-time surplus posting and pickups.',
    },
  ],

  conflictAccountId: 'GLK-001',
  conflictNodeName: 'Green Leaf Midtown',
  conflictSuggestions: [
    'Provision under a branch-specific alias, e.g. downtown@<domain>.',
    'Promote the existing user to multi-unit manager across both zones.',
  ],
};

/** Pre-filled example, matching the designs' worked example. */
export const SAMPLE_DRAFT = {
  businessName: 'Green Leaf Kitchen',
  branchName: 'Downtown Branch (GLK-DT-01)',
  category: 'Restaurant (Sit-down / Fine dining)' as const,
  operatingArea: 'Downtown District (Zone 03)',
  pickupLocation: 'Main pickup counter (Rear loading dock on 4th Ave)',
  contactName: 'Marcus Vance',
  contactRole: 'General Manager',
  phone: '+1 (555) 382-9104',
  loginEmail: 'operations@greenleafkitchen.com',
};
