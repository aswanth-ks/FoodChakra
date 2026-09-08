import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import { SAMPLE_ESCALATION } from './data/sampleQueue';
import { SAMPLE_NETWORK_STATUS } from './data/sampleRescues';
import type { EscalationData } from './data/queueTypes';
import type { NetworkStatus } from './data/rescueTypes';

/**
 * "FoodLoop Rescue Operations Console — Smart Escalation".
 *
 * Faithful translation of the Stitch design
 * (screen `04f4eb21239a4f9fa5a3c4108afcf70f`).
 *
 * The escalation desk: everything currently widening its search, the focused
 * case's five-stage progress, what the system is doing about it, and the
 * operator's levers.
 *
 * **Design divergence:** the mock redraws the sidebar and status bar, and
 * labels two nav entries differently ("Directory & Fleet", "Activity"); the
 * shared console layout is used instead so the nav does not change between
 * pages.
 */
export default function EscalationPage({
  data = SAMPLE_ESCALATION,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: EscalationData;
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();

  const [focusId, setFocusId] = useState(
    data.rows.find((row) => row.focused)?.id ?? data.rows[0]?.id ?? '',
  );
  // The design previews the expansion before committing to it.
  const [confirming, setConfirming] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  return (
    <ConsoleLayout
      title="Smart Rescue Escalation"
      subtitle="Coverage and operator intervention"
      statusStrip={
        <ConsoleStatusStrip
          activeRescues={status.activeRescues}
          needIntervention={data.escalatingCount}
          pickupsApproaching={status.pickupsApproaching}
          version={status.consoleVersion}
        />
      }
    >
      <nav className="crumbs t-body-sm" aria-label="Breadcrumb">
        <Link to="/overview">Escalations</Link>
        <span aria-hidden="true">›</span>
        <span className="muted">Smart Rescue Escalation</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">Smart Rescue Escalation</h1>
          <p className="t-body-md">
            Manage rescue opportunities that require additional coverage or
            operator intervention.
          </p>
        </div>
        <div className="intro__actions">
          <span className="pill t-label-sm">
            <span className="dot dot--pulse" style={{ background: 'var(--success)' }} />
            Live Feed
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
            <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
              radar
            </span>
            <span className="t-label-md upper">Escalation Center</span>
            <span aria-hidden="true">•</span>
            <span className="t-label-sm" style={{ opacity: 0.85 }}>
              {data.escalatingCount} rescues currently escalating
            </span>
          </div>
          <p className="t-body-md" style={{ margin: '6px 0 0', opacity: 0.9 }}>
            {data.bannerBody}
          </p>
        </div>
        <span className="pill t-label-sm coverbanner__pill">
          <span className="dot dot--pulse" style={{ background: 'var(--success-bright)' }} />
          Escalation system active
        </span>
      </section>

      <section className="card">
        <div className="section-head">
          <div>
            <h2 className="t-headline-sm" style={{ margin: 0 }}>
              Active Escalations Queue
            </h2>
            <span className="t-body-sm muted">
              Sorted by time-to-spoilage limit
            </span>
          </div>
          <span className="t-label-sm muted">Real-time Priority</span>
        </div>

        <div className="tablewrap">
          <table className="dtable">
            <thead>
              <tr>
                <th scope="col">Rescue</th>
                <th scope="col">Restaurant</th>
                <th scope="col">Current State</th>
                <th scope="col">Escalation Stage</th>
                <th scope="col">Time Remaining</th>
                <th scope="col">
                  <span className="visually-hidden">Action</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {data.rows.map((row) => {
                const focused = row.id === focusId;
                return (
                  <tr
                    key={row.id}
                    className={focused ? 'dtable__row--on' : undefined}
                    onClick={() => setFocusId(row.id)}
                  >
                    <td>
                      <span className="t-body-md" style={{ fontWeight: 600 }}>
                        {row.id}
                      </span>
                      <span className="dtable__sub t-body-sm muted">
                        {row.quantityLabel}
                      </span>
                    </td>
                    <td>
                      <span className="t-body-md">{row.restaurant}</span>
                      <span className="dtable__sub t-body-sm muted">
                        {row.locality}
                      </span>
                    </td>
                    <td>
                      <span className="dtable__state t-body-sm">
                        <span
                          className="icon"
                          style={{ fontSize: 15, color: 'var(--warning-deep)' }}
                          aria-hidden="true"
                        >
                          {row.stateIcon}
                        </span>
                        {row.state}
                      </span>
                    </td>
                    <td className="t-body-sm muted">{row.stageLabel}</td>
                    <td>
                      <span
                        className="t-metric"
                        style={{ fontSize: 13, color: 'var(--error)' }}
                      >
                        {row.minutesRemaining} min remaining
                      </span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      {focused ? (
                        <span className="chip t-label-sm" style={{
                          background: 'var(--secondary-container)',
                          color: 'var(--primary)',
                        }}>
                          Active Focus
                        </span>
                      ) : (
                        <button
                          className="btn btn--quiet"
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            setFocusId(row.id);
                          }}
                        >
                          Open
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section className="escsplit">
        <div className="detailsplit__col">
          <article className="card">
            <div className="section-head">
              <div>
                <span className="t-label-sm upper" style={{ color: 'var(--error)' }}>
                  Critical Focus
                </span>
                <h2 className="t-headline-lg" style={{ margin: '2px 0 0' }}>
                  {data.focusTitle}
                </h2>
                <span className="t-body-sm muted">{data.focusPartner}</span>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div className="t-label-sm upper muted">{data.savedLabel}</div>
                <div className="t-metric" style={{ fontSize: 18, color: 'var(--primary)' }}>
                  {data.savedValue}
                </div>
              </div>
            </div>

            <div style={{ padding: '12px 16px 0' }}>
              <span className="t-body-sm muted">{data.focusNote}</span>
            </div>

            <div className="alertcard alertcard--error" style={{ margin: 16 }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                warning
              </span>
              <div>
                <div className="t-body-md" style={{ fontWeight: 600 }}>
                  {data.issueTitle}
                </div>
                <div className="t-body-sm">{data.issueBody}</div>
              </div>
            </div>
          </article>

          <article className="card">
            <div className="section-head">
              <div>
                <h2 className="t-headline-sm" style={{ margin: 0 }}>
                  Escalation Progress Lifecycle
                </h2>
                <span className="t-body-sm muted">{data.stageSummary}</span>
              </div>
              <span className="t-label-sm muted">
                Stage {data.currentStage} of {data.stageCount} In Effect
              </span>
            </div>

            <ol className="stages">
              {data.stages.map((stage) => {
                const done = stage.index < data.currentStage;
                const active = stage.index === data.currentStage;
                const pending = stage.index === data.currentStage + 1;
                const state = done
                  ? 'done'
                  : active
                    ? 'active'
                    : pending
                      ? 'next'
                      : 'idle';
                return (
                  <li className={`stages__item stages__item--${state}`} key={stage.index}>
                    <span className="stages__marker">
                      {done ? (
                        <span className="icon" style={{ fontSize: 15 }}>
                          check_circle
                        </span>
                      ) : (
                        <span className="t-label-sm">{stage.index}</span>
                      )}
                    </span>
                    <span className="t-label-sm upper stages__label">
                      Stage {stage.index}
                    </span>
                    <span className="t-body-sm" style={{ fontWeight: 600 }}>
                      {stage.title}
                    </span>
                    <span className="t-label-sm muted">{stage.stamp}</span>
                  </li>
                );
              })}
            </ol>
          </article>

          <article className="card">
            <div className="section-head">
              <h2 className="t-headline-sm" style={{ margin: 0 }}>
                Active Operational Telemetry
              </h2>
            </div>
            <div className="factors">
              {data.telemetry.map((tile) => (
                <div className="factors__col" key={tile.label}>
                  <span className="t-label-sm upper muted">{tile.label}</span>
                  <span
                    className="icon"
                    style={{ fontSize: 20, color: 'var(--primary)' }}
                    aria-hidden="true"
                  >
                    {tile.icon}
                  </span>
                  <div className="t-body-md" style={{ fontWeight: 600 }}>
                    {tile.value}
                  </div>
                  <div className="t-body-sm muted">{tile.caption}</div>
                </div>
              ))}
            </div>
          </article>

          <article className="card">
            <div className="section-head">
              <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
                <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                  history
                </span>
                Escalation Audit &amp; Event Timeline
              </h2>
              <span className="t-label-sm muted">ID: {data.auditId}</span>
            </div>

            <ol className="audit">
              {data.events.map((event, index) => (
                <li className="audit__row" key={event.heading}>
                  <span className="audit__rail" aria-hidden="true">
                    <span
                      className="audit__dot"
                      style={{
                        background:
                          index === 0 ? 'var(--error)' : 'var(--outline-variant)',
                      }}
                    />
                  </span>
                  <div className="audit__body">
                    <div className="audit__title">
                      <span className="t-body-md" style={{ fontWeight: 600 }}>
                        {event.heading}
                      </span>
                      <span className="t-label-sm muted">{event.source}</span>
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
                Operator Actions
              </h2>
              <span className="t-label-sm muted cardtitle">
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  admin_panel_settings
                </span>
                {data.authorisation}
              </span>
            </div>

            <div className="controls">
              {confirming && (
                <div className="confirmbox">
                  <div className="confirmbox__head">
                    <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
                      satellite_alt
                    </span>
                    <span className="t-body-md" style={{ fontWeight: 600 }}>
                      {data.pendingTitle}
                    </span>
                  </div>
                  <p className="t-body-sm muted" style={{ margin: '4px 0 10px' }}>
                    {data.pendingBody}
                  </p>
                  <div className="confirmbox__actions">
                    <button
                      className="btn btn--primary"
                      type="button"
                      onClick={() => {
                        setConfirming(false);
                        setNotice(
                          'Coverage was not expanded — broadcasting to ' +
                            'additional couriers needs the Phase 14 dispatch ' +
                            'service.',
                        );
                      }}
                    >
                      Confirm Expansion
                    </button>
                    <button
                      className="btn btn--quiet"
                      type="button"
                      onClick={() => setConfirming(false)}
                    >
                      Dismiss
                    </button>
                  </div>
                </div>
              )}

              <div className="actionlist actionlist--boxed">
                {data.actions.map((action) => {
                  // Expanding coverage is the one lever with a screen behind
                  // it; the rest act on the dispatch service directly.
                  const expands = action.icon === 'broadcast_on_personal';
                  return (
                    <button
                      key={action.label}
                      type="button"
                      className="actionrow"
                      disabled={!expands}
                      onClick={expands ? () => setConfirming(true) : undefined}
                      title={
                        expands
                          ? 'Preview the expansion'
                          : 'Needs the Phase 14 dispatch service'
                      }
                    >
                      <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                        {action.icon}
                      </span>
                      <span className="actionrow__body">
                        <span className="t-body-md">{action.label}</span>
                      </span>
                      <span className="icon muted" style={{ fontSize: 16 }} aria-hidden="true">
                        chevron_right
                      </span>
                    </button>
                  );
                })}

                <button
                  type="button"
                  className="actionrow actionrow--danger"
                  disabled
                  title="Needs supervisor override, and the Phase 14 rescue service"
                >
                  <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                    {data.dangerAction.icon}
                  </span>
                  <span className="actionrow__body">
                    <span className="t-body-md">{data.dangerAction.label}</span>
                    <span className="t-label-sm muted">
                      {data.dangerAction.caution}
                    </span>
                  </span>
                </button>
              </div>

              <button
                className="btn btn--quiet btn--block"
                type="button"
                onClick={() => navigate(`/live-rescues/${focusId}/coverage`)}
              >
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  map
                </span>
                View dynamic coverage
              </button>
            </div>
          </article>

          <article className="card">
            <div className="section-head">
              <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
                <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                  verified
                </span>
                How Smart Escalation Works
              </h2>
            </div>

            <div style={{ padding: 16 }}>
              <p className="t-body-sm muted" style={{ margin: 0 }}>
                {data.principlesBody}
              </p>
            </div>

            <div className="actionlist">
              {data.principles.map((principle) => (
                <div className="principle" key={principle.title}>
                  <span
                    className="icon"
                    style={{ fontSize: 18, color: 'var(--primary)' }}
                    aria-hidden="true"
                  >
                    {principle.icon}
                  </span>
                  <div>
                    <div className="t-body-md" style={{ fontWeight: 600 }}>
                      {principle.title}
                    </div>
                    <div className="t-body-sm muted">{principle.body}</div>
                  </div>
                </div>
              ))}
            </div>
          </article>
        </div>
      </section>
    </ConsoleLayout>
  );
}
