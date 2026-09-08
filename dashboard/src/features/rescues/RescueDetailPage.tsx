import { useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import InterventionDrawer from './components/InterventionDrawer';
import LifecycleTimeline from './components/LifecycleTimeline';
import {
  SAMPLE_NETWORK_STATUS,
  SAMPLE_RESCUE_DETAIL,
} from './data/sampleRescues';
import {
  LIFECYCLE_ORDER,
  type NetworkStatus,
  type RescueDetail,
} from './data/rescueTypes';

/**
 * "FoodLoop Rescue Operations Console — Rescue Opportunity Detail".
 *
 * Faithful translation of the Stitch design
 * (screen `804145037efc453ab479efffe0867c56`).
 *
 * Everything about one rescue in trouble: its lifecycle position, the surplus
 * and partner behind it, the countdown, the operator's levers, and the audit
 * trail. Reached from the Live Rescue Map.
 *
 * **Design divergence:** as on the map screen, the mock's generic "Item
 * Details" mobile app bar is omitted, and the sidebar comes from the shared
 * console layout rather than being redrawn per page.
 */
export default function RescueDetailPage({
  detail = SAMPLE_RESCUE_DETAIL,
  status = SAMPLE_NETWORK_STATUS,
}: {
  detail?: RescueDetail;
  status?: NetworkStatus;
}) {
  const { id } = useParams();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  // Both "Intervene" and the "Expand rescue coverage" action open the
  // coverage screen, which is where a widening decision is actually made.
  const coveragePath = `/live-rescues/${id ?? detail.reference}/coverage`;

  // The map's "Intervene" deep-links straight into the drawer.
  const [drawerOpen, setDrawerOpen] = useState(
    searchParams.get('intervene') === '1',
  );
  const [applied, setApplied] = useState<string | null>(null);

  function closeDrawer() {
    setDrawerOpen(false);
    if (searchParams.has('intervene')) {
      searchParams.delete('intervene');
      setSearchParams(searchParams, { replace: true });
    }
  }

  const currentIndex = detail.lifecycle.findIndex(
    (entry) => entry.stamp !== 'Pending' && entry.step === 'searching',
  );
  const activeIndex =
    currentIndex >= 0 ? currentIndex : LIFECYCLE_ORDER.indexOf('searching');

  // How much of the pickup window is gone, for the countdown bar.
  const elapsed = Math.max(
    0,
    Math.min(1, 1 - detail.minutesRemaining / detail.windowMinutes),
  );

  return (
    <ConsoleLayout
      title="Rescue Details"
      subtitle={`Rescue #${detail.reference}`}
      statusStrip={
        <ConsoleStatusStrip
          activeRescues={status.activeRescues}
          needIntervention={status.needIntervention}
          version={status.consoleVersion}
        />
      }
    >
      <nav className="crumbs t-body-sm" aria-label="Breadcrumb">
        <Link to="/live-rescues">Live Rescues</Link>
        <span aria-hidden="true">/</span>
        <span className="muted">Rescue Details</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">{detail.partner}</h1>
          <p className="t-body-md">
            Rescue #{detail.reference}
            {id && id !== detail.reference && (
              /* The fixtures only carry one rescue, so a different id in the
                 URL still renders this record. Phase 14 looks it up. */
              <span className="muted"> · showing sample record</span>
            )}
          </p>
        </div>

        <div className="intro__actions">
          <span
            className="chip t-label-sm"
            style={{
              background: 'var(--error-container)',
              color: 'var(--on-error-container)',
              height: 28,
              padding: '0 10px',
            }}
          >
            <span className="dot dot--pulse" style={{ background: 'var(--error)' }} />
            LIVE
          </span>
          <span className="pill t-label-md" style={{ color: 'var(--error)' }}>
            <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
              schedule
            </span>
            {detail.minutesRemaining} min remaining
          </span>
          <button
            className="btn btn--danger"
            type="button"
            onClick={() => navigate(coveragePath)}
          >
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              bolt
            </span>
            Intervene
          </button>
        </div>
      </section>

      {applied && (
        <div className="alertcard alertcard--info t-body-sm" role="status">
          <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
            info
          </span>
          <div>{applied}</div>
          <button
            className="iconbtn"
            type="button"
            onClick={() => setApplied(null)}
            aria-label="Dismiss"
            style={{ marginLeft: 'auto' }}
          >
            <span className="icon" style={{ fontSize: 18 }}>
              close
            </span>
          </button>
        </div>
      )}

      <section className="card incident">
        <div className="incident__head">
          <span
            className="chip t-label-sm"
            style={{
              background: 'var(--error)',
              color: 'var(--on-error)',
            }}
          >
            CRITICAL FOCUS
          </span>
          <span className="t-label-sm upper muted">{detail.stateLabel}</span>
          <span className="t-headline-sm" style={{ marginLeft: 'auto' }}>
            {detail.headline}
          </span>
        </div>

        <div className="incident__body">
          <span
            className="icon"
            style={{ fontSize: 22, color: 'var(--error)' }}
            aria-hidden="true"
          >
            emergency_home
          </span>
          <div>
            <div className="t-body-md" style={{ fontWeight: 600 }}>
              {detail.bannerTitle}
            </div>
            <div className="t-body-sm muted">{detail.bannerBody}</div>
          </div>
          <div className="incident__cta">
            <button
              className="btn btn--danger"
              type="button"
              onClick={() => setDrawerOpen(true)}
            >
              <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                priority_high
              </span>
              Resolve Immediate
            </button>
            <span className="t-label-sm muted">{detail.autoTimeout}</span>
          </div>
        </div>
      </section>

      <section className="card" style={{ padding: '18px 16px' }}>
        <LifecycleTimeline entries={detail.lifecycle} currentIndex={activeIndex} />
      </section>

      <section className="detailsplit">
        <div className="detailsplit__col">
          <article className="card">
            <div className="section-head">
              <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
                <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                  inventory_2
                </span>
                Surplus Details
              </h2>
              <span
                className="chip t-label-md"
                style={{
                  background: 'var(--primary-fixed)',
                  color: 'var(--on-primary-fixed)',
                }}
              >
                {detail.quantityLabel}
              </span>
            </div>

            <dl className="factlist">
              {detail.surplusFacts.map((fact) => (
                <div className="factlist__row" key={fact.label}>
                  <dt className="t-body-sm muted">{fact.label}</dt>
                  <dd className="t-body-md">{fact.value}</dd>
                </div>
              ))}
            </dl>

            <div className="alertcard alertcard--good">
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                verified_user
              </span>
              <div>
                <div className="t-body-md" style={{ fontWeight: 600 }}>
                  Safety Protocol Verification
                </div>
                <div className="t-body-sm muted">{detail.safetyNote}</div>
              </div>
            </div>
          </article>

          <article className="card">
            <div className="section-head">
              <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
                <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                  restaurant
                </span>
                Restaurant Partner
              </h2>
              {detail.partnerVerified && (
                <span
                  className="chip t-label-sm"
                  style={{
                    background: 'var(--primary-fixed)',
                    color: 'var(--on-primary-fixed)',
                  }}
                >
                  <span className="icon" style={{ fontSize: 13 }} aria-hidden="true">
                    check_circle
                  </span>
                  Verified partner
                </span>
              )}
            </div>

            <div style={{ padding: 16 }}>
              <div className="t-body-lg" style={{ fontWeight: 600 }}>
                {detail.partner}
              </div>
              <div className="t-body-sm muted">{detail.partnerAddress}</div>
              <div className="t-body-sm muted" style={{ marginTop: 4 }}>
                {detail.partnerTier}
              </div>
              {/* The partner profile is its own console page, not built yet. */}
              <button
                className="linkbtn t-label-md"
                type="button"
                disabled
                title="Partner profile — not built yet"
              >
                View Partner Profile →
              </button>
            </div>

            <div className="alertcard alertcard--neutral">
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                notes
              </span>
              <div>
                <div className="t-body-md" style={{ fontWeight: 600 }}>
                  Contact Operator Note
                </div>
                <div className="t-body-sm muted">{detail.operatorNote}</div>
              </div>
            </div>
          </article>
        </div>

        <div className="detailsplit__col">
          <article className="card">
            <div className="section-head">
              <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
                <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                  timer
                </span>
                Rescue Progress &amp; Escalation
              </h2>
              <span
                className="chip t-label-sm"
                style={{
                  background: 'var(--error-container)',
                  color: 'var(--on-error-container)',
                }}
              >
                EXPIRATION IMMINENT
              </span>
            </div>

            <div style={{ padding: 16 }}>
              <div className="countdown__head">
                <span className="t-metric" style={{ fontSize: 22, color: 'var(--error)' }}>
                  {detail.minutesRemaining} min remaining
                </span>
                <span className="t-body-sm muted">
                  of {detail.windowMinutes} min window
                </span>
              </div>

              <div
                className="progress"
                role="progressbar"
                aria-valuenow={Math.round(elapsed * 100)}
                aria-valuemin={0}
                aria-valuemax={100}
                aria-label="Pickup window elapsed"
              >
                <span
                  className="progress__fill"
                  style={{ width: `${elapsed * 100}%` }}
                />
              </div>

              <div className="countdown__ends t-label-sm muted">
                <span>{detail.windowOpens}</span>
                <span>{detail.windowCloses}</span>
              </div>

              <div className="tagstack">
                {detail.escalationTags.map((tag) => (
                  <span className="tagrow t-body-sm" key={tag.label}>
                    <span
                      className="icon"
                      style={{ fontSize: 16, color: 'var(--warning-deep)' }}
                      aria-hidden="true"
                    >
                      {tag.icon}
                    </span>
                    {tag.label}
                  </span>
                ))}
              </div>

              <p className="t-body-sm muted" style={{ margin: '10px 0 0' }}>
                {detail.escalationBody}
              </p>
            </div>
          </article>

          <article className="card">
            <div className="section-head">
              <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
                <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                  tune
                </span>
                Operator Actions
              </h2>
              <span className="t-label-sm muted">{detail.privilegeLabel}</span>
            </div>

            <div className="actionlist">
              {detail.actions.map((action) => {
                // Expanding coverage has a screen of its own; the rest act on
                // the rescue service directly, which does not exist yet.
                const expands = action.icon === 'cell_tower';

                return (
                <button
                  key={action.label}
                  type="button"
                  className={`actionrow${
                    action.destructive ? ' actionrow--danger' : ''
                  }`}
                  disabled={!expands}
                  onClick={expands ? () => navigate(coveragePath) : undefined}
                  title={
                    expands
                      ? 'Open dynamic rescue coverage'
                      : 'Needs the Phase 14 rescue service'
                  }
                >
                  <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                    {action.icon}
                  </span>
                  <span className="actionrow__body">
                    <span className="t-body-md">{action.label}</span>
                    {action.caution && (
                      <span className="t-label-sm muted">{action.caution}</span>
                    )}
                  </span>
                  <span className="icon muted" style={{ fontSize: 16 }} aria-hidden="true">
                    chevron_right
                  </span>
                </button>
                );
              })}
            </div>
          </article>
        </div>
      </section>

      <section className="card">
        <div className="section-head">
          <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
            <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
              history
            </span>
            Rescue Activity &amp; Audit Log
          </h2>
          <span className="t-label-sm muted">Updated just now</span>
        </div>

        <ol className="audit">
          {detail.audit.map((entry, index) => (
            <li className="audit__row" key={`${entry.time}-${entry.title}`}>
              <span className="audit__rail" aria-hidden="true">
                <span
                  className="audit__dot"
                  style={{
                    background: index === 0 ? 'var(--error)' : 'var(--outline-variant)',
                  }}
                />
              </span>
              <div className="audit__body">
                <div className="audit__title">
                  <span className="t-body-md" style={{ fontWeight: 600 }}>
                    {entry.title}
                  </span>
                  <span className="t-label-sm muted">{entry.time}</span>
                </div>
                <div className="t-body-sm muted">{entry.detail}</div>
              </div>
            </li>
          ))}
        </ol>
      </section>

      <InterventionDrawer
        detail={detail}
        open={drawerOpen}
        onClose={closeDrawer}
        onApply={(optionTitle, note) => {
          closeDrawer();
          setApplied(
            `"${optionTitle}" was not sent — applying an intervention needs ` +
              `the Phase 14 rescue service.` +
              (note.trim() ? ` Dispatch note kept: “${note.trim()}”.` : ''),
          );
        }}
      />
    </ConsoleLayout>
  );
}
