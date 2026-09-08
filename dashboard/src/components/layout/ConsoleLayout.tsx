import type { ReactNode } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { clearSession, readSession } from '../../features/auth/session';

/** One sidebar destination. */
interface NavEntry {
  label: string;
  icon: string;
  /** Absent while the page does not exist yet. */
  path?: string;
  count?: number;
  /** Renders the count in the error colour, as Escalations does. */
  alert?: boolean;
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
  { label: 'Zero-Waste Network', icon: 'hub' },
  { label: 'Analytics', icon: 'insights', path: '/analytics' },
];

const MANAGEMENT_NAV: NavEntry[] = [
  { label: 'Restaurants', icon: 'storefront' },
  { label: 'Rescuers', icon: 'sports_motorsports' },
  { label: 'Locations', icon: 'distance' },
  { label: 'Activity', icon: 'history' },
];

/**
 * The console frame: fixed sidebar, fixed topbar, scrolling content.
 *
 * Overview, Live Rescues, Rescue Queue, Escalations and Analytics are built;
 * every other destination renders as a disabled row rather than a link to
 * nothing. They keep their counts because those come from the same fixtures
 * the built pages use.
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

  function handleSignOut() {
    clearSession();
    navigate('/login', { replace: true });
  }

  return (
    <div className="shell">
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

          <div className="navitem navitem--disabled" aria-disabled="true">
            <span className="navitem__main">
              <span className="icon" style={{ fontSize: 18 }}>
                settings
              </span>
              <span className="t-body-sm">Settings</span>
            </span>
          </div>

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
        {entries.map((entry) => {
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
                <span className="icon" style={{ fontSize: 18 }}>
                  {entry.icon}
                </span>
                <span className="t-body-sm truncate">{entry.label}</span>
              </span>
              {count}
            </>
          );

          if (entry.path === undefined) {
            return (
              <div
                key={entry.label}
                className="navitem navitem--disabled"
                aria-disabled="true"
                title={`${entry.label} — not built yet`}
              >
                {body}
              </div>
            );
          }

          // The detail page lives under /live-rescues, so a prefix match keeps
          // the parent destination highlighted while drilled in.
          const active =
            pathname === entry.path || pathname.startsWith(`${entry.path}/`);

          return (
            <Link
              key={entry.label}
              to={entry.path}
              className={`navitem${active ? ' navitem--active' : ''}`}
              aria-current={active ? 'page' : undefined}
            >
              {body}
            </Link>
          );
        })}
      </nav>
    </div>
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
