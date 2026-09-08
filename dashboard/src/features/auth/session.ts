/**
 * Console sign-in state.
 *
 * **This is a stand-in, not authentication.** Nothing is verified: no
 * password is checked, no token is issued, and the "session" is a flag in
 * `localStorage` that anyone can set from the browser console. It exists so
 * the console has a front door and the Overview page is reachable behind it
 * while the real thing does not exist yet.
 *
 * Phase 3 replaces this with the backend's ops-staff login: a real credential
 * exchange, an httpOnly session cookie or short-lived token, and a server
 * that refuses every console API call without one. The guard here must never
 * be what protects operational data — it only decides which screen renders.
 */

const STORAGE_KEY = 'foodloop.console.session';

/** The signed-in operator, as shown in the sidebar. */
export interface ConsoleSession {
  email: string;
  name: string;
  role: string;
  /** Initials for the avatar, e.g. "AS". */
  initials: string;
}

/** Reads the stored session, or null when signed out. */
export function readSession(): ConsoleSession | null {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed: unknown = JSON.parse(raw);
    if (
      typeof parsed === 'object' &&
      parsed !== null &&
      typeof (parsed as ConsoleSession).email === 'string'
    ) {
      return parsed as ConsoleSession;
    }
    return null;
  } catch {
    // Private mode, cleared storage, or corrupt JSON: treat as signed out
    // rather than breaking the app.
    return null;
  }
}

export function writeSession(session: ConsoleSession): void {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
  } catch {
    // Storage can be unavailable; the session then lasts for this page only.
  }
}

export function clearSession(): void {
  try {
    window.localStorage.removeItem(STORAGE_KEY);
  } catch {
    // Nothing to do.
  }
}

/**
 * Ops staff sign in with a FoodLoop address, mirroring the rule the mobile
 * app uses for partner accounts. Same caveat: a domain is not an
 * authorization, and the server has to make this decision in Phase 3.
 */
export const OPS_EMAIL_DOMAIN = 'foodloop.com';

/** Derives the display name and initials from the address. */
export function sessionForEmail(email: string): ConsoleSession {
  const normalised = email.trim().toLowerCase();
  const local = normalised.split('@')[0] ?? 'operator';

  const words = local
    .split(/[.\-_+]/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1));

  const name = words.length > 0 ? words.join(' ') : 'Operator';
  const initials =
    words
      .slice(0, 2)
      .map((word) => word.charAt(0))
      .join('') || 'OP';

  return { email: normalised, name, role: 'Lead Dispatch', initials };
}

/** Whether an address may sign in to the console at all. */
export function isOpsEmail(email: string): boolean {
  const normalised = email.trim().toLowerCase();
  const at = normalised.lastIndexOf('@');
  if (at === -1) return false;
  return normalised.slice(at + 1) === OPS_EMAIL_DOMAIN;
}
