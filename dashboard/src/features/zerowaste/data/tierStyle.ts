import type { RecoveryTier } from './zeroWasteTypes';

/**
 * One colour per rung of the recovery hierarchy, best to worst.
 *
 * The ramp is deliberately monotonic - green through amber to red - so a chip
 * reads as "how good is this outcome" before anyone reads the word. Landfill
 * is the error colour because on this tier it *is* the failure case.
 *
 * These live apart from the components that use them so the component module
 * exports components only, which is what React Fast Refresh needs.
 */
export const TIER_COLOR: Record<RecoveryTier, string> = {
  human: 'var(--success)',
  animal_feed: 'var(--primary)',
  composting: 'var(--warning)',
  energy: 'var(--warning-deep)',
  landfill: 'var(--error)',
};

export const TIER_BG: Record<RecoveryTier, string> = {
  human: 'var(--primary-fixed)',
  animal_feed: 'var(--secondary-container)',
  composting: 'var(--warning-bg)',
  energy: 'var(--warning-bg)',
  landfill: 'var(--error-container)',
};

export const TIER_ICON: Record<RecoveryTier, string> = {
  human: 'restaurant',
  animal_feed: 'pets',
  composting: 'compost',
  energy: 'bolt',
  landfill: 'delete',
};
