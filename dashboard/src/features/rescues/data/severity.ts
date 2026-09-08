import type { RescueSeverity } from './rescueTypes';

/**
 * How each severity reads across the map, the list and the filters.
 *
 * Kept out of the component files so the map's constants are not re-exported
 * alongside a component, which breaks React Fast Refresh.
 */

export const SEVERITY_COLOR: Record<RescueSeverity, string> = {
  critical: 'var(--error)',
  attention: 'var(--warning)',
  active: 'var(--map-route-green)',
  completed: 'var(--map-node-idle)',
};

export const SEVERITY_LABEL: Record<RescueSeverity, string> = {
  critical: 'Critical',
  attention: 'Attention',
  active: 'Active',
  completed: 'Completed',
};

export const SEVERITY_ICON: Record<RescueSeverity, string> = {
  critical: 'warning',
  attention: 'schedule',
  active: 'local_shipping',
  completed: 'check_circle',
};
