import { useState } from 'react';
import { Link } from 'react-router-dom';
import ConsoleLayout from '../../components/layout/ConsoleLayout';
import { readSession } from '../auth/session';
import {
  DEFAULT_PREFERENCES,
  DENSITY_LABEL,
  LANDING_LABEL,
  readPreferences,
  writePreferences,
  type ConsolePreferences,
  type Density,
  type LandingPage,
} from './data/preferences';

/**
 * "FoodLoop Rescue Operations Console - Settings".
 *
 * **No Stitch design.** Built from the console's own tokens and primitives,
 * like Console Sign In and the three Management pages.
 *
 * The page is split along one line, and that line is the whole point of its
 * layout: **what this browser draws** versus **what the network does**.
 *
 * - *Console preferences* are real. They change only local rendering, so they
 *   work today, persist in `localStorage`, and take effect immediately. They
 *   are per-browser and not attached to an account, because there is no
 *   account yet - the page says so rather than implying they sync.
 * - *Everything else* - alert thresholds, dispatch and coverage defaults,
 *   access policy, audit retention, team access - is disabled. None of it can
 *   be a browser setting: each applies to every operator, changes what real
 *   people are dispatched to do, and has to be recorded in the audit trail.
 *   A local toggle that appeared to set a coverage default would be actively
 *   misleading, so those controls state what they need instead of pretending.
 *
 * **Security note:** there is deliberately no password field, no MFA toggle
 * that claims to work, and no API token generator on this page. Console
 * sign-in is not yet authentication (see `features/auth/session.ts`); a
 * credential UI in front of a stand-in would imply a protection that does not
 * exist. Phase 3 brings the real ops login, and these controls with it.
 */
export default function SettingsPage() {
  const session = readSession();

  const [preferences, setPreferences] =
    useState<ConsolePreferences>(readPreferences);
  const [saved, setSaved] = useState(false);

  /** Applies a preference change: state, storage, and the frame around us. */
  function update(patch: Partial<ConsolePreferences>) {
    const next = { ...preferences, ...patch };
    setPreferences(next);
    writePreferences(next);
    setSaved(true);
  }

  function restoreDefaults() {
    setPreferences(DEFAULT_PREFERENCES);
    writePreferences(DEFAULT_PREFERENCES);
    setSaved(true);
  }

  const isDefault =
    preferences.landing === DEFAULT_PREFERENCES.landing &&
    preferences.density === DEFAULT_PREFERENCES.density;

  return (
    <ConsoleLayout
      title="Settings"
      subtitle={session?.email ?? 'Not signed in'}
    >
      <nav className="crumbs t-body-sm" aria-label="Breadcrumb">
        <span className="muted">Console</span>
        <span aria-hidden="true">&rsaquo;</span>
        <span className="muted">Settings</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">Settings</h1>
          <p className="t-body-md">
            How this console behaves for you, and the network-wide policy it
            runs under.
          </p>
        </div>
        <div className="intro__actions">
          {saved && (
            <span className="pill t-label-sm">
              <span className="dot" style={{ background: 'var(--success)' }} />
              Preferences saved
            </span>
          )}
          <button
            className="btn btn--quiet"
            type="button"
            onClick={restoreDefaults}
            disabled={isDefault}
          >
            Restore defaults
          </button>
        </div>
      </section>

      {/* Operator profile - read-only, because the session behind it is a
          stand-in and nothing on the page can change a real account. */}
      <section className="card">
        <div className="section-head">
          <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
            Operator
          </h2>
          <span className="chip t-label-sm">EU-WEST</span>
        </div>

        <div className="statgrid">
          <SettingStat label="Name" value={session?.name ?? 'Not signed in'} />
          <SettingStat label="Role" value={session?.role ?? '-'} />
          <SettingStat label="Email" value={session?.email ?? '-'} />
          <SettingStat label="Region" value="EU-WEST" />
        </div>

        <div className="alertcard alertcard--info">
          <span className="t-body-sm">
            <strong>This profile is not an account.</strong> The console session
            is a local flag, and the name and role above are derived from the
            address that was typed at sign-in. Editing a profile, changing a
            password or enrolling a second factor all need the Phase 3 ops
            login, so none of them are offered here.
          </span>
        </div>
      </section>

      {/* The one section that genuinely works. */}
      <section className="card">
        <div className="section-head">
          <div style={{ minWidth: 0 }}>
            <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
              Console Preferences
            </h2>
            <span className="t-body-sm muted">
              Display only - these take effect immediately
            </span>
          </div>
          <span
            className="chip t-label-sm"
            style={{
              background: 'var(--primary-fixed)',
              color: 'var(--on-primary-fixed)',
            }}
          >
            Active
          </span>
        </div>

        <dl className="factlist">
          <div className="factlist__row">
            <div style={{ minWidth: 0 }}>
              <dt className="t-body-md" style={{ fontWeight: 600 }}>
                Landing page
              </dt>
              <dd className="t-body-sm muted" style={{ margin: 0 }}>
                Where the console opens after you sign in.
              </dd>
            </div>
            <dd style={{ margin: 0 }}>
              <label className="visually-hidden" htmlFor="pref-landing">
                Landing page
              </label>
              <select
                id="pref-landing"
                className="select"
                style={{ height: 36 }}
                value={preferences.landing}
                onChange={(event) =>
                  update({ landing: event.target.value as LandingPage })
                }
              >
                {(Object.keys(LANDING_LABEL) as LandingPage[]).map((option) => (
                  <option key={option} value={option}>
                    {LANDING_LABEL[option]}
                  </option>
                ))}
              </select>
            </dd>
          </div>

          <div className="factlist__row">
            <div style={{ minWidth: 0 }}>
              <dt className="t-body-md" style={{ fontWeight: 600 }}>
                Table density
              </dt>
              <dd className="t-body-sm muted" style={{ margin: 0 }}>
                Row height in the queue, rescuer, partner and log tables.
              </dd>
            </div>
            <dd style={{ margin: 0 }}>
              <div className="segmented" role="group" aria-label="Table density">
                {(Object.keys(DENSITY_LABEL) as Density[]).map((option) => (
                  <button
                    key={option}
                    type="button"
                    aria-pressed={preferences.density === option}
                    className={`segmented__btn t-label-md${
                      preferences.density === option
                        ? ' segmented__btn--on'
                        : ''
                    }`}
                    onClick={() => update({ density: option })}
                  >
                    {DENSITY_LABEL[option]}
                  </button>
                ))}
              </div>
            </dd>
          </div>
        </dl>

        <div className="alertcard alertcard--neutral">
          <span className="t-body-sm">
            Saved in this browser only. There is no operator account to attach
            them to yet, so signing in elsewhere starts from the defaults.
          </span>
        </div>
      </section>

      {/* Everything below steers the network and cannot be a local setting. */}
      <section className="card">
        <div className="section-head">
          <div style={{ minWidth: 0 }}>
            <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
              Dispatch &amp; Coverage Defaults
            </h2>
            <span className="t-body-sm muted">
              Applies to every operator and every rescue in the region
            </span>
          </div>
          <span className="chip t-label-sm">Needs Phase 14 API</span>
        </div>

        <PolicyRow
          label="Standard coverage radius"
          detail="The default dispatch band for a new zone. Per-zone values are set on Locations."
          value="2.5 km - 4.0 km by zone"
          reason="Changing a dispatch radius changes who is pinged for a real rescue."
        />
        <PolicyRow
          label="Auto-expand threshold"
          detail="Unmatched rescues inside the standard band before coverage widens automatically."
          value="4 rescues"
          reason="This rule is what Smart Escalation acts on; it has to be server state."
        />
        <PolicyRow
          label="Maximum expanded radius"
          detail="The ceiling dynamic coverage may widen a zone to."
          value="6.0 km"
          reason="A ceiling enforced only in the browser is not a ceiling."
        />
        <PolicyRow
          label="Pickup window warning"
          detail="How long before a window closes the console raises a warning."
          value="15 minutes"
          reason="Drives the countdown treatment on every operational page."
        />

        <div className="controls" style={{ paddingTop: 0 }}>
          <Link className="btn btn--quiet btn--block" to="/locations">
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              distance
            </span>
            Review per-zone coverage on Locations
          </Link>
        </div>
      </section>

      <section className="card">
        <div className="section-head">
          <div style={{ minWidth: 0 }}>
            <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
              Alerting
            </h2>
            <span className="t-body-sm muted">
              When the console and the on-call rota are notified
            </span>
          </div>
          <span className="chip t-label-sm">Needs Phase 14 API</span>
        </div>

        <PolicyRow
          label="Escalation alerts"
          detail="Raise an alert when a rescue crosses into critical severity."
          value="On - all operators"
          reason="An alert nobody receives is worse than no alert; delivery is server-side."
        />
        <PolicyRow
          label="Failed dispatch alerts"
          detail="Notify when a rescue exhausts expanded coverage and falls through."
          value="On - on-call only"
          reason="Routing to the on-call rota needs the notification service."
        />
        <PolicyRow
          label="Daily operations digest"
          detail="Summary of rescues, interventions and unmatched volume."
          value="08:00 UTC"
          reason="Scheduled email is sent by the backend, not the browser."
        />
      </section>

      <section className="card">
        <div className="section-head">
          <div style={{ minWidth: 0 }}>
            <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
              Access &amp; Audit
            </h2>
            <span className="t-body-sm muted">
              Who may sign in, and how long the record is kept
            </span>
          </div>
          <span className="chip t-label-sm">Needs Phase 3 auth</span>
        </div>

        <PolicyRow
          label="Operator accounts"
          detail="Who holds console access, and at what scope."
          value="Managed by the backend"
          reason="There is no account store yet; sign-in is a local flag."
        />
        <PolicyRow
          label="Two-factor authentication"
          detail="Required second factor for console sign-in."
          value="Not enforced"
          reason="A second factor in front of a stand-in login would protect nothing."
        />
        <PolicyRow
          label="Session timeout"
          detail="Idle time before an operator session ends."
          value="Not enforced"
          reason="Only the server issuing the session can expire it."
        />
        <PolicyRow
          label="Audit retention"
          detail="How long Activity Log records are kept before archival."
          value="Managed by the backend"
          reason="Retention is a compliance control; the console must not be able to shorten it."
        />

        <div className="alertcard alertcard--error">
          <span className="t-body-sm">
            <strong>Console sign-in is not authentication yet.</strong> Any{' '}
            <code>@foodloop.com</code> address opens the console and no
            credential is checked. Until the Phase 3 ops login lands, treat
            everything behind this front door as unprotected.
          </span>
        </div>

        <div className="controls" style={{ paddingTop: 0 }}>
          <Link className="btn btn--quiet btn--block" to="/activity">
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              history
            </span>
            Open the Activity Log
          </Link>
        </div>
      </section>
    </ConsoleLayout>
  );
}

/**
 * One network-wide policy: what it is, what it currently is set to, and the
 * reason the console cannot change it here.
 */
function PolicyRow({
  label,
  detail,
  value,
  reason,
}: {
  label: string;
  detail: string;
  value: string;
  reason: string;
}) {
  return (
    <div className="factlist">
      <div className="factlist__row">
        <div style={{ minWidth: 0 }}>
          <span className="t-body-md" style={{ fontWeight: 600 }}>
            {label}
          </span>
          <span className="dtable__sub t-body-sm muted">{detail}</span>
          <span className="dtable__sub t-label-sm muted">{reason}</span>
        </div>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            flexShrink: 0,
          }}
        >
          <span className="t-body-sm muted">{value}</span>
          <button className="btn btn--quiet" type="button" disabled title={reason}>
            Edit
          </button>
        </div>
      </div>
    </div>
  );
}

function SettingStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="statgrid__cell">
      <span className="t-label-sm upper muted">{label}</span>
      <span className="t-body-md truncate" style={{ fontWeight: 600 }}>
        {value}
      </span>
    </div>
  );
}
