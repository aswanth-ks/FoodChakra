import type { ReactNode } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { clearSession, readSession } from '../../features/auth/session';
import { readPreferences } from '../../features/settings/data/preferences';

/** One sidebar destination. */
interface NavEntry {
  label: string;
  icon: string;
  /** Absent while the page does not exist yet. */
  path?: string;
  count?: number;
  /** Renders the count in the error colour, as Escalations does. */
  alert?: boolean;
  /**
   * Nested destinations, rendered indented beneath this entry.
   *
   * A section with several sibling pages lists them here rather than hiding
   * them behind in-page tabs, so every page the console has is reachable from
   * the sidebar.
   */
  children?: NavEntry[];
}

const MAIN_NAV: NavEntry[] = [
  { label: 'Overview', icon: 'grid_view', path: '/overview' },
  {
    label: 'Live Rescues',
    icon: 'local_shipping',
    path: '/live-rescues',
    count: 42,
  },
  { label: 'Rescue Queue', icon: 'inbox', path: '/rescue-queue', count: 42 },
  {
    label: 'Escalations',
    icon: 'warning',
    path: '/escalations',
    count: 3,
    alert: true,
  },
  {
    label: 'Zero-Waste Network',
    icon: 'hub',
    path: '/zero-waste',
    children: [
      { label: 'Overview', icon: 'dashboard', path: '/zero-waste' },
      {
        label: 'Fallback Opportunity',
        icon: 'pending_actions',
        path: '/zero-waste/fallback',
      },
      {
        label: 'Recovery Partners',
        icon: 'factory',
        path: '/zero-waste/partners',
      },
      { label: 'Routing', icon: 'alt_route', path: '/zero-waste/routing' },
      {
        label: 'Recovery History',
        icon: 'history_toggle_off',
        path: '/zero-waste/history',
      },
    ],
  },
  { label: 'Analytics', icon: 'insights', path: '/analytics' },
];

const MANAGEMENT_NAV: NavEntry[] = [
  { label: 'Restaurants', icon: 'storefront', path: '/restaurants' },
  {
    label: 'Onboard Restaurant',
    icon: 'add_business',
    path: '/restaurants/onboard',
  },
  { label: 'Rescuers', icon: 'sports_motorsports', path: '/rescuers' },
  { label: 'Locations', icon: 'distance', path: '/locations' },
  { label: 'Activity', icon: 'history', path: '/activity' },
];

/**
 * The console frame: fixed sidebar, fixed topbar, scrolling content.
 *
 * Every destination is built. Counts come from the same fixtures the built
 * pages use. The Zero-Waste Network entry covers four pages; its three
 * top-level views are reached from a section sub-nav on the pages themselves
 * rather than from three more sidebar rows.
 */
export default function ConsoleLayout({
  title,
  subtitle,
  children,
  statusStrip,
}: {
  title: string;
  subtitle: string;
  children: ReactNode;
  /** The fixed bottom status strip, on the pages whose designs have one. */
  statusStrip?: ReactNode;
}) {
  const navigate = useNavigate();
  const location = useLocation();
  const session = readSession();
  // Display-only preference, read per render so a change on the Settings page
  // applies to the frame immediately.
  const { density } = readPreferences();

  function handleSignOut() {
    clearSession();
    navigate('/login', { replace: true });
  }

  return (
    <div className="shell" data-density={density}>
      <aside className="sidebar">
        <div className="sidebar__head">
          <div className="sidebar__brand">
            <div className="sidebar__mark" aria-hidden="true">
              FL
            </div>
            <div style={{ minWidth: 0 }}>
              <div className="t-headline-sm truncate" style={{ fontSize: 15 }}>
                FoodLoop
              </div>
              <div className="t-label-sm muted truncate">
                Operations Console
              </div>
            </div>
          </div>
          <span className="sidebar__region t-label-sm">EU-WEST</span>
        </div>

        <div className="sidebar__nav">
          <NavGroup label="Main" entries={MAIN_NAV} pathname={location.pathname} />
          <div
            style={{
              height: 1,
              background: 'rgba(193,200,193,0.3)',
              margin: '0 8px',
            }}
          />
          <NavGroup
            label="Management"
            entries={MANAGEMENT_NAV}
            pathname={location.pathname}
          />
        </div>

        <div className="sidebar__foot">
          <div className="syncrow">
            <span
              style={{ display: 'flex', alignItems: 'center', gap: 6 }}
              className="t-label-sm muted"
            >
              <span
                className="dot"
                style={{ background: 'var(--success-bright)' }}
              />
              Network Sync
            </span>
            <span className="t-label-sm" style={{ fontWeight: 600 }}>
              Normal
            </span>
          </div>

          <Link
            to="/settings"
            className={`navitem${
              location.pathname === '/settings' ? ' navitem--active' : ''
            }`}
            aria-current={location.pathname === '/settings' ? 'page' : undefined}
          >
            <span className="navitem__main">
              <span className="icon" style={{ fontSize: 18 }}>
                settings
              </span>
              <span className="t-body-sm">Settings</span>
            </span>
          </Link>

          <button
            className="userrow"
            type="button"
            onClick={handleSignOut}
            title="Sign out"
          >
            <span className="sidebar__brand">
              <span className="avatar t-label-md" aria-hidden="true">
                {session?.initials ?? 'OP'}
              </span>
              <span style={{ minWidth: 0 }}>
                <span
                  className="t-body-sm truncate"
                  style={{ display: 'block', fontWeight: 600 }}
                >
                  {session?.name ?? 'Operator'}
                </span>
                <span className="t-label-sm muted truncate" style={{ display: 'block' }}>
                  {session?.role ?? 'Operations'}
                </span>
              </span>
            </span>
            <span
              className="icon muted"
              style={{ fontSize: 18 }}
              aria-hidden="true"
            >
              logout
            </span>
          </button>
        </div>
      </aside>

      <div className="shell__body">
        <header className="topbar">
          <div className="topbar__title">
            <span className="t-headline-sm" style={{ fontSize: 16 }}>
              {title}
            </span>
            <span className="t-label-sm muted">{subtitle}</span>
          </div>

          <div className="topbar__search">
            <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
              search
            </span>
            <input
              type="search"
              placeholder="Search restaurants, rescues, rescuers..."
              aria-label="Search the rescue network"
              // Search needs the Phase 3 console API; the field is present but
              // does not query anything yet.
              disabled
            />
            <span className="kbd t-label-sm">⌘K</span>
          </div>

          <div className="topbar__right">
            <span className="pill t-label-sm" style={{ height: 28 }}>
              <span
                className="dot dot--pulse"
                style={{ background: 'var(--success)' }}
              />
              System operational
              <span className="muted">· 24ms</span>
            </span>
            <span className="t-label-sm muted">Updated just now</span>
            <span className="bellwrap">
              <button className="iconbtn" type="button" aria-label="Notifications">
                <span className="icon" style={{ fontSize: 20 }}>
                  notifications
                </span>
              </button>
              <span className="bellwrap__badge">3</span>
            </span>
            <span className="avatar t-label-md" aria-hidden="true">
              {session?.initials ?? 'OP'}
            </span>
          </div>
        </header>

        <main className={`shell__main${statusStrip ? ' shell__main--strip' : ''}`}>
          <div className="shell__inner">{children}</div>
        </main>

        {statusStrip}
      </div>
    </div>
  );
}

function NavGroup({
  label,
  entries,
  pathname,
}: {
  label: string;
  entries: NavEntry[];
  pathname: string;
}) {
  return (
    <div className="navgroup">
      <span className="navgroup__label t-label-sm upper">{label}</span>
      <nav>
        {entries.map((entry) => (
          <NavRow key={entry.label} entry={entry} pathname={pathname} />
        ))}
      </nav>
    </div>
  );
}

/** One sidebar destination, plus its nested pages when it has any. */
function NavRow({
  entry,
  pathname,
  child = false,
  sectionRoot,
}: {
  entry: NavEntry;
  pathname: string;
  /** Renders the indented treatment used for nested pages. */
  child?: boolean;
  /** The parent section's path, passed down to nested rows. */
  sectionRoot?: string;
}) {
  const count =
    entry.count === undefined ? null : (
      <span
        className={[
          'navitem__count',
          't-label-sm',
          entry.alert ? 'navitem__count--alert' : '',
        ].join(' ')}
      >
        {entry.count}
      </span>
    );

  const body = (
    <>
      <span className="navitem__main">
        <span className="icon" style={{ fontSize: child ? 16 : 18 }}>
          {entry.icon}
        </span>
        <span className="t-body-sm truncate">{entry.label}</span>
      </span>
      {count}
    </>
  );

  const base = `navitem${child ? ' navitem--child' : ''}`;

  if (entry.path === undefined) {
    return (
      <div
        className={`${base} navitem--disabled`}
        aria-disabled="true"
        title={`${entry.label} — not built yet`}
      >
        {body}
      </div>
    );
  }

  const inSection =
    pathname === entry.path || pathname.startsWith(`${entry.path}/`);

  // A nested row whose path *is* the section root - the section's own Overview
  // - has to match exactly. Prefix matching there would light it up on every
  // page in the section, since every one of those paths starts with it.
  // Deeper nested rows still prefix-match, so Fallback Opportunity stays lit
  // while viewing one case at /zero-waste/fallback/:id.
  const isSectionRoot = child && entry.path === sectionRoot;

  // Three matching rules, because these rows mean different things:
  //
  // - A nested row matches exactly at the section root, by prefix below it.
  // - A section header never takes the selected treatment itself; one of its
  //   children is the page being viewed, and two highlighted rows for one page
  //   reads as two selections.
  // - Everything else prefix-matches, so a parent stays highlighted while
  //   drilled into a detail page (/live-rescues/:id).
  const active = child
    ? isSectionRoot
      ? pathname === entry.path
      : inSection
    : entry.children
      ? false
      : inSection;

  // The section header still reads as current whenever any page beneath it is
  // open - including a detail view like /zero-waste/fallback/:id, which has no
  // nested row of its own to carry the selection.
  const sectionOpen = entry.children !== undefined && inSection;

  return (
    <>
      <Link
        to={entry.path}
        className={`${base}${active ? ' navitem--active' : ''}${
          sectionOpen ? ' navitem--section' : ''
        }`}
        aria-current={active ? 'page' : undefined}
      >
        {body}
      </Link>

      {entry.children && (
        <div className="navnest">
          {entry.children.map((nested) => (
            <NavRow
              key={nested.label}
              entry={nested}
              pathname={pathname}
              child
              sectionRoot={entry.path}
            />
          ))}
        </div>
      )}
    </>
  );
}

/** The fixed strip along the bottom of the operational pages. */
export function ConsoleStatusStrip({
  activeRescues,
  needIntervention,
  pickupsApproaching,
  expandedCoverage,
  version,
}: {
  activeRescues: number;
  needIntervention: number;
  pickupsApproaching?: number;
  expandedCoverage?: number;
  version: string;
}) {
  return (
    <footer className="statusstrip t-label-sm">
      <div className="statusstrip__group">
        <span className="statusstrip__item">
          <span className="dot dot--pulse" style={{ background: 'var(--success)' }} />
          Network operational
        </span>
        <span className="statusstrip__sep" aria-hidden="true" />
        <span className="statusstrip__item">{activeRescues} active rescues</span>
        <span className="statusstrip__sep" aria-hidden="true" />
        {expandedCoverage !== undefined && (
          <>
            <span className="statusstrip__item">
              {expandedCoverage} expanded coverage
            </span>
            <span className="statusstrip__sep" aria-hidden="true" />
          </>
        )}
        <span className="statusstrip__item" style={{ color: 'var(--error)' }}>
          {needIntervention} require intervention
        </span>
        {pickupsApproaching !== undefined && (
          <>
            <span className="statusstrip__sep" aria-hidden="true" />
            <span
              className="statusstrip__item"
              style={{ color: 'var(--warning-deep)' }}
            >
              {pickupsApproaching} pickups approaching
            </span>
          </>
        )}
      </div>

      <div className="statusstrip__group muted">
        <span>{version}</span>
        <span className="statusstrip__sep" aria-hidden="true" />
        <span className="statusstrip__item">
          <span className="icon" style={{ fontSize: 13 }} aria-hidden="true">
            lock
          </span>
          Secure TLS Connected
        </span>
      </div>
    </footer>
  );
}
