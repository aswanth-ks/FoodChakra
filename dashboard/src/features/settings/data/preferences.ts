/**
 * Console display preferences.
 *
 * These are the settings the console can honestly honour today: they change
 * only what this browser renders, so nothing here needs a backend to be real.
 * They are stored per-browser in `localStorage` and are **not** attached to an
 * operator account, because there is no account yet — signing in on another
 * machine gets the defaults back. Phase 3 moves them onto the ops profile.
 *
 * Everything on the Settings page that steers the *network* — alert
 * thresholds, dispatch defaults, coverage rules, session policy, audit
 * retention — is deliberately not here. Those cannot be a browser preference:
 * they have to be server state, applied for every operator and recorded in the
 * audit trail.
 */

const STORAGE_KEY = 'foodloop.console.preferences';

/** Where the console opens after sign-in. */
export type LandingPage =
  | '/overview'
  | '/live-rescues'
  | '/rescue-queue'
  | '/escalations';

export const LANDING_LABEL: Record<LandingPage, string> = {
  '/overview': 'Overview',
  '/live-rescues': 'Live Rescue Map',
  '/rescue-queue': 'Rescue Queue',
  '/escalations': 'Smart Escalation',
};

/** Row height of the console's dense tables. */
export type Density = 'comfortable' | 'compact';

export const DENSITY_LABEL: Record<Density, string> = {
  comfortable: 'Comfortable',
  compact: 'Compact',
};

export interface ConsolePreferences {
  landing: LandingPage;
  density: Density;
}

export const DEFAULT_PREFERENCES: ConsolePreferences = {
  landing: '/overview',
  density: 'comfortable',
};

const LANDING_VALUES: LandingPage[] = [
  '/overview',
  '/live-rescues',
  '/rescue-queue',
  '/escalations',
];

const DENSITY_VALUES: Density[] = ['comfortable', 'compact'];

/**
 * Reads stored preferences, falling back to the defaults.
 *
 * Every field is validated rather than trusted: this value comes from
 * `localStorage`, which the operator can edit by hand, and a bad `landing`
 * would send the console to a route that does not exist.
 */
export function readPreferences(): ConsolePreferences {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return DEFAULT_PREFERENCES;

    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== 'object' || parsed === null) {
      return DEFAULT_PREFERENCES;
    }

    const candidate = parsed as Partial<ConsolePreferences>;
    const landing = LANDING_VALUES.includes(candidate.landing as LandingPage)
      ? (candidate.landing as LandingPage)
      : DEFAULT_PREFERENCES.landing;
    const density = DENSITY_VALUES.includes(candidate.density as Density)
      ? (candidate.density as Density)
      : DEFAULT_PREFERENCES.density;

    return { landing, density };
  } catch {
    // Private mode, cleared storage, or corrupt JSON: the defaults are always
    // a working console.
    return DEFAULT_PREFERENCES;
  }
}

export function writePreferences(preferences: ConsolePreferences): void {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(preferences));
  } catch {
    // Storage can be unavailable; the choice then lasts for this page only.
  }
}

export function clearPreferences(): void {
  try {
    window.localStorage.removeItem(STORAGE_KEY);
  } catch {
    // Nothing to do.
  }
}
