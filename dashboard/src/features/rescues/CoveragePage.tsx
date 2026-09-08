import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import CoverageMap from './components/CoverageMap';
import { SAMPLE_COVERAGE } from './data/sampleCoverage';
import { SAMPLE_NETWORK_STATUS } from './data/sampleRescues';
import {
  COVERAGE_LABEL,
  COVERAGE_ORDER,
  type CoverageData,
} from './data/coverageTypes';
import type { NetworkStatus } from './data/rescueTypes';

/**
 * "FoodLoop Rescue Operations Console — Dynamic Rescue Coverage".
 *
 * Faithful translation of the Stitch design
 * (screen `d944fd65322b4b6c883e39a2bac4159a`).
 *
 * Where an operator lands from "Expand coverage" or "Intervene": what the
 * search radius currently is, why it widened, who is inside each band, and
 * whether to widen it again.
 *
 * **Design divergence:** the mock redraws the sidebar and its own status bar;
 * both come from the shared console layout here, as on the other console
 * pages. Its nav also labels two entries differently ("Activity Log",
 * "Operations Core"); the shared sidebar's wording is kept so the nav does
 * not change between pages.
 */
export default function CoveragePage({
  data = SAMPLE_COVERAGE,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: CoverageData;
  status?: NetworkStatus;
}) {
  const { id } = useParams();

  // The design shows the expand button revealing an inline confirmation
  // rather than acting immediately — coverage changes are broadcast to real
  // couriers, so it asks first.
  const [confirming, setConfirming] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  const currentIndex = COVERAGE_ORDER.indexOf(data.currentLevel);
  const backTo = id ? `/live-rescues/${id}` : '/live-rescues';

  return (
    <ConsoleLayout
      title="Dynamic Rescue Coverage"
      subtitle={data.zone}
      statusStrip={
        <ConsoleStatusStrip
          activeRescues={status.activeRescues}
          needIntervention={status.needIntervention}
          expandedCoverage={data.expandedCount}
          version={status.consoleVersion}
        />
      }
    >
      <nav className="crumbs t-body-sm" aria-label="Breadcrumb">
        <Link to="/live-rescues">Live Rescues</Link>
        <span aria-hidden="true">›</span>
        <Link to={backTo}>Rescue Details</Link>
        <span aria-hidden="true">›</span>
        <span className="muted">Dynamic Rescue Coverage</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">
            Dynamic Rescue Coverage{' '}
            <span className="muted" style={{ fontWeight: 400, fontSize: 16 }}>
              · {data.zone}
            </span>
          </h1>
          <p className="t-body-md">
            Adapt rescue coverage as availability, urgency, and pickup
            conditions change.
          </p>
        </div>

        <div className="intro__actions">
          <span className="pill t-label-sm">
            <span className="dot dot--pulse" style={{ background: 'var(--success)' }} />
            LIVE FEED
          </span>
          <span className="t-label-sm muted">Updated just now</span>
        </div>
      </section>

      {notice && (
        <div className="alertcard alertcard--info t-body-sm" role="status">
          <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
            info
          </span>
          <div>{notice}</div>
          <button
            className="iconbtn"
            type="button"
            onClick={() => setNotice(null)}
            aria-label="Dismiss"
            style={{ marginLeft: 'auto' }}
          >
            <span className="icon" style={{ fontSize: 18 }}>
              close
            </span>
          </button>
        </div>
      )}

      <section className="card coverbanner">
        <div className="coverbanner__copy">
          <div className="coverbanner__tags">
            <span className="t-label-sm upper" style={{ opacity: 0.75 }}>
              Coverage Network
            </span>
            <span aria-hidden="true">•</span>
            <span className="t-label-md upper">{data.bannerTitle}</span>
          </div>
          <p className="t-body-md" style={{ margin: '6px 0 0', opacity: 0.9 }}>
            {data.bannerBody}
          </p>
        </div>

        <div className="coverbanner__metrics">
          <BannerMetric label="Active rescues" value={data.activeRescues} />
          <BannerMetric label="Expanded" value={data.expandedCount} />
          <BannerMetric label="Review required" value={data.reviewRequired} alert />
        </div>
      </section>

      <section className="mapsplit">
        <div className="detailsplit__col">
          <div className="card opsmap">
            <div className="section-head">
              <div>
                <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
                  <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                    explore
                  </span>
                  Live Coverage Network
                </h2>
                <span className="t-body-sm muted">
                  Current rescue coverage across active opportunities and
                  nearby responders.
                </span>
              </div>
            </div>
            <CoverageMap data={data} />
          </div>

          <article className="card">
            <div className="section-head">
              <h2 className="t-headline-sm" style={{ margin: 0 }}>
                Why Coverage Changed
              </h2>
              <span className="t-label-sm muted">{data.trigger}</span>
            </div>
            <div className="factors">
              {data.factors.map((factor) => (
                <div className="factors__col" key={factor.title}>
                  <span className="icon" style={{ fontSize: 20, color: 'var(--primary)' }} aria-hidden="true">
                    {factor.icon}
                  </span>
                  <div className="t-body-md" style={{ fontWeight: 600 }}>
                    {factor.title}
                  </div>
                  <div className="t-body-sm muted">{factor.finding}</div>
                  <div className="factors__metric">
                    <span className="t-label-sm muted">{factor.metricLabel}</span>
                    <span className="t-label-md">{factor.metricValue}</span>
                  </div>
                </div>
              ))}
            </div>
          </article>

          <article className="card">
            <div className="section-head">
              <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
                <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                  schedule
                </span>
                Coverage Events Timeline
              </h2>
              <span className="t-label-sm muted">Real-time log</span>
            </div>
            <ol className="audit">
              {data.events.map((event, index) => (
                <li className="audit__row" key={`${event.time}-${event.title}`}>
                  <span className="audit__rail" aria-hidden="true">
                    <span
                      className="audit__dot"
                      style={{
                        background:
                          index === data.events.length - 1
                            ? 'var(--error)'
                            : 'var(--outline-variant)',
                      }}
                    />
                  </span>
                  <div className="audit__body">
                    <div className="audit__title">
                      <span className="t-body-md" style={{ fontWeight: 600 }}>
                        {event.title}
                      </span>
                      <span className="t-label-sm muted">{event.time}</span>
                    </div>
                    <div className="t-body-sm muted">{event.detail}</div>
                  </div>
                </li>
              ))}
            </ol>
          </article>
        </div>

        <div className="detailsplit__col">
          <article className="card">
            <div className="section-head">
              <h2 className="t-headline-sm" style={{ margin: 0 }}>
                Selected Rescue
              </h2>
              <span
                className="chip t-label-sm"
                style={{
                  background: 'var(--error-container)',
                  color: 'var(--on-error-container)',
                }}
              >
                {data.severityLabel}
              </span>
            </div>

            <div style={{ padding: 16 }}>
              <div className="t-headline-sm">{data.partner}</div>
              <div className="tagrow t-body-sm" style={{ marginTop: 10, background: 'var(--surface-container-low)', borderColor: 'rgba(193,200,193,0.5)', color: 'var(--on-surface)' }}>
                <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
                  inventory_2
                </span>
                {data.quantityLine}
              </div>
              <p className="t-body-sm muted" style={{ margin: '8px 0 0' }}>
                {data.handlingNote}
              </p>

              <dl className="factlist" style={{ padding: '8px 0 0' }}>
                <div className="factlist__row">
                  <dt className="t-body-sm muted">Current state</dt>
                  <dd className="t-body-md">{data.currentState}</dd>
                </div>
                <div className="factlist__row">
                  <dt className="t-body-sm muted">Time remaining</dt>
                  <dd className="t-body-md" style={{ color: 'var(--error)' }}>
                    {data.minutesRemaining} min
                  </dd>
                </div>
                <div className="factlist__row">
                  <dt className="t-body-sm muted">Pickup window</dt>
                  <dd className="t-body-md">{data.pickupWindow}</dd>
                </div>
              </dl>
            </div>
          </article>

          <article className="card">
            <div className="section-head">
              <h2 className="t-headline-sm" style={{ margin: 0 }}>
                Coverage Status Progression
              </h2>
              <span className="t-label-sm muted">
                Level {currentIndex + 1} of {COVERAGE_ORDER.length}
              </span>
            </div>

            <ol className="levels">
              {COVERAGE_ORDER.map((level, index) => {
                const done = index < currentIndex;
                const active = index === currentIndex;
                return (
                  <li
                    className={`levels__row${
                      done
                        ? ' levels__row--done'
                        : active
                          ? ' levels__row--active'
                          : ''
                    }`}
                    key={level}
                  >
                    <span className="t-label-md">
                      {index + 1}. {COVERAGE_LABEL[level]}
                    </span>
                    <span className="levels__state t-label-sm">
                      {done && (
                        <>
                          <span className="icon" style={{ fontSize: 14 }} aria-hidden="true">
                            check
                          </span>
                          Complete
                        </>
                      )}
                      {active && (
                        <>
                          <span className="icon" style={{ fontSize: 14 }} aria-hidden="true">
                            check_circle
                          </span>
                          Active
                        </>
                      )}
                      {!done && !active && 'Available'}
                    </span>
                  </li>
                );
              })}
            </ol>

            <p className="levels__note t-body-sm">“{data.levelExplanation}”</p>
          </article>

          <article className="card">
            <div className="section-head">
              <h2 className="t-headline-sm" style={{ margin: 0 }}>
                Operator Coverage Controls
              </h2>
            </div>

            <div className="controls">
              {!confirming ? (
                <button
                  className="btn btn--primary btn--block"
                  type="button"
                  onClick={() => setConfirming(true)}
                >
                  <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
                    radar
                  </span>
                  Expand coverage
                </button>
              ) : (
                <div className="confirmbox">
                  <div className="confirmbox__head">
                    <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
                      info
                    </span>
                    <span className="t-body-md" style={{ fontWeight: 600 }}>
                      Pending Action: Expand rescue coverage?
                    </span>
                  </div>
                  <p className="t-body-sm muted" style={{ margin: '4px 0 10px' }}>
                    This will continue the rescue search through additional
                    available coverage.
                  </p>
                  <div className="confirmbox__actions">
                    <button
                      className="btn btn--primary"
                      type="button"
                      onClick={() => {
                        setConfirming(false);
                        // Widening coverage broadcasts to real couriers, which
                        // needs the Phase 14 dispatch service.
                        setNotice(
                          'Coverage was not expanded — broadcasting to ' +
                            'additional courier pools needs the Phase 14 ' +
                            'dispatch service.',
                        );
                      }}
                    >
                      Confirm expansion
                    </button>
                    <button
                      className="btn btn--quiet"
                      type="button"
                      onClick={() => setConfirming(false)}
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              )}

              {/* The remaining levers all act on the dispatch service. */}
              <button className="btn btn--quiet btn--block" type="button" disabled>
                Maintain current coverage
              </button>
              <button className="btn btn--quiet btn--block" type="button" disabled>
                Open escalation controls
              </button>
              <button className="btn btn--danger btn--block" type="button" disabled>
                <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
                  emergency
                </span>
                Start alternative recovery
              </button>
            </div>
          </article>
        </div>
      </section>

      <section className="coverstats">
        {data.stats.map((stat) => (
          <article className="card coverstats__card" key={stat.label}>
            <div>
              <div className="t-label-sm upper muted">{stat.label}</div>
              <div className="t-metric" style={{ fontSize: 20, color: 'var(--primary)' }}>
                {stat.value}
              </div>
            </div>
            <span className="icon muted" style={{ fontSize: 22 }} aria-hidden="true">
              {stat.icon}
            </span>
          </article>
        ))}
      </section>
    </ConsoleLayout>
  );
}

function BannerMetric({
  label,
  value,
  alert,
}: {
  label: string;
  value: number;
  alert?: boolean;
}) {
  return (
    <div className="coverbanner__metric">
      <span
        className="t-metric"
        style={{ fontSize: 26, color: alert ? 'var(--error-container)' : 'inherit' }}
      >
        {value}
      </span>
      <span className="t-label-sm upper" style={{ opacity: 0.75 }}>
        {label}
      </span>
    </div>
  );
}
