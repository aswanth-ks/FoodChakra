import type { ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
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
  { label: 'Live Rescues', icon: 'local_shipping', count: 42 },
  { label: 'Rescue Queue', icon: 'inbox' },
  { label: 'Escalations', icon: 'warning', count: 3, alert: true },
  { label: 'Zero-Waste Network', icon: 'hub' },
  { label: 'Analytics', icon: 'insights' },
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
 * Only Overview is built, so every other destination renders as a disabled
 * row rather than a link to nothing. They keep their counts because those
 * come from the same fixtures the Overview page uses.
 */
export default function ConsoleLayout({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle: string;
  children: ReactNode;
}) {
  const navigate = useNavigate();
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
          <NavGroup label="Main" entries={MAIN_NAV} />
          <div
            style={{
              height: 1,
              background: 'rgba(193,200,193,0.3)',
              margin: '0 8px',
            }}
          />
          <NavGroup label="Management" entries={MANAGEMENT_NAV} />
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

        <main className="shell__main">
          <div className="shell__inner">{children}</div>
        </main>
      </div>
    </div>
  );
}

function NavGroup({ label, entries }: { label: string; entries: NavEntry[] }) {
  return (
    <div className="navgroup">
      <span className="navgroup__label t-label-sm upper">{label}</span>
      <nav>
        {entries.map((entry) => {
          const built = entry.path !== undefined;
          return (
            <div
              key={entry.label}
              className={[
                'navitem',
                built ? 'navitem--active' : 'navitem--disabled',
              ].join(' ')}
              aria-current={built ? 'page' : undefined}
              aria-disabled={built ? undefined : true}
              title={built ? undefined : `${entry.label} — not built yet`}
            >
              <span className="navitem__main">
                <span className="icon" style={{ fontSize: 18 }}>
                  {entry.icon}
                </span>
                <span className="t-body-sm truncate">{entry.label}</span>
              </span>
              {entry.count !== undefined && (
                <span
                  className={[
                    'navitem__count',
                    't-label-sm',
                    entry.alert ? 'navitem__count--alert' : '',
                  ].join(' ')}
                >
                  {entry.count}
                </span>
              )}
            </div>
          );
        })}
      </nav>
    </div>
  );
}
