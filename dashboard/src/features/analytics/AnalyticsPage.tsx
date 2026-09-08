import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import PerformanceChart from './components/PerformanceChart';
import { SAMPLE_ANALYTICS } from './data/sampleAnalytics';
import { SAMPLE_NETWORK_STATUS } from '../rescues/data/sampleRescues';
import type { AnalyticsData, RateRow, SectorRow } from './data/analyticsTypes';
import type { NetworkStatus } from '../rescues/data/rescueTypes';

const STATUS_TONE: Record<SectorRow['status'], string> = {
  Healthy: 'var(--success)',
  Monitor: 'var(--warning-deep)',
  'Needs attention': 'var(--error)',
};

/**
 * "FoodLoop Rescue Operations Console — Analytics".
 *
 * Faithful translation of the Stitch design
 * (screen `425247d520024816b1f7cc5891946928`).
 *
 * The reporting view: headline metrics, daily volume, the publication-to-
 * handover funnel, matching and pickup performance, where interventions go,
 * and which sectors are struggling.
 *
 * **Design divergence:** the mock has no sidebar of its own; it is placed in
 * the shared console layout so the nav is consistent with every other page.
 */
export default function AnalyticsPage({
  data = SAMPLE_ANALYTICS,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: AnalyticsData;
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();

  const [scope, setScope] = useState(data.scopes[0] ?? 'All Sectors');
  const [showCompleted, setShowCompleted] = useState(true);
  const [showUnresolved, setShowUnresolved] = useState(true);

  return (
    <ConsoleLayout
      title="Performance & Logistics Analytics"
      subtitle={data.reportingWindow}
      statusStrip={
        <ConsoleStatusStrip
          activeRescues={status.activeRescues}
          needIntervention={status.needIntervention}
          pickupsApproaching={status.pickupsApproaching}
          version={status.consoleVersion}
        />
      }
    >
      <section className="intro">
        <div>
          <div className="t-label-sm upper muted">
            {data.contextLabel} · {data.reportingWindow}
          </div>
          <h1 className="t-headline-lg">Performance &amp; Logistics Analytics</h1>
        </div>

        <div className="intro__actions">
          <div className="segmented" role="group" aria-label="Reporting scope">
            {data.scopes.map((option) => (
              <button
                key={option}
                type="button"
                aria-pressed={scope === option}
                className={`segmented__btn t-label-md${
                  scope === option ? ' segmented__btn--on' : ''
                }`}
                onClick={() => setScope(option)}
              >
                {option}
              </button>
            ))}
          </div>
          <span className="t-label-sm muted">{data.syncedLabel}</span>
        </div>
      </section>

      <section className="kpis" aria-label="Headline metrics">
        {data.metrics.map((metric) => (
          <article className="card kpi" key={metric.label}>
            <div className="kpi__head">
              <span className="t-label-sm upper muted">{metric.label}</span>
              <span className="icon muted" style={{ fontSize: 18 }} aria-hidden="true">
                {metric.icon}
              </span>
            </div>
            <div className="kpi__value">
              <span
                className="t-metric"
                style={{
                  fontSize: 30,
                  lineHeight: '38px',
                  color: 'var(--primary)',
                  fontWeight: 700,
                }}
              >
                {metric.value}
              </span>
              <span
                className="kpi__trend t-label-sm"
                style={{
                  color: metric.improved ? 'var(--success)' : 'var(--error)',
                }}
              >
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  {metric.direction === 'up' ? 'arrow_upward' : 'arrow_downward'}
                </span>
                {metric.delta}
              </span>
            </div>
            <div className="kpi__foot t-body-sm truncate">{metric.caption}</div>
          </article>
        ))}
      </section>

      <section className="card">
        <div className="section-head">
          <div>
            <h2 className="t-headline-sm" style={{ margin: 0 }}>
              Rescue Performance
            </h2>
            <span className="t-body-sm muted">
              Daily volume of completed vs unresolved rescue opportunities
            </span>
          </div>
          <div className="chart__legend">
            <button
              type="button"
              className={`legendkey t-label-sm${showCompleted ? '' : ' legendkey--off'}`}
              aria-pressed={showCompleted}
              onClick={() => setShowCompleted((value) => !value)}
            >
              <span className="legendkey__swatch" style={{ background: 'var(--primary)' }} />
              Completed ({data.completedTotal})
            </button>
            <button
              type="button"
              className={`legendkey t-label-sm${showUnresolved ? '' : ' legendkey--off'}`}
              aria-pressed={showUnresolved}
              onClick={() => setShowUnresolved((value) => !value)}
            >
              <span
                className="legendkey__swatch legendkey__swatch--dashed"
                style={{ background: 'var(--error)' }}
              />
              Unresolved ({data.unresolvedTotal})
            </button>
          </div>
        </div>

        <div style={{ padding: 16 }}>
          <PerformanceChart
            daily={data.daily}
            showCompleted={showCompleted}
            showUnresolved={showUnresolved}
          />
        </div>

        <div className="queue__foot t-body-sm">
          <span className="dtable__state">
            <span
              className="icon"
              style={{ fontSize: 16, color: 'var(--success)' }}
              aria-hidden="true"
            >
              check_circle
            </span>
            {data.chartNote}
          </span>
          <span className="t-label-sm muted">{data.variance}</span>
        </div>
      </section>

      <section className="card">
        <div className="section-head">
          <div>
            <h2 className="t-headline-sm" style={{ margin: 0 }}>
              Rescue Operational Funnel
            </h2>
            <span className="t-body-sm muted">
              End-to-end conversion efficiency from surplus publication to
              physical handover
            </span>
          </div>
          <span className="t-label-sm muted">
            Net Funnel Conversion:{' '}
            <strong style={{ color: 'var(--primary)' }}>
              {data.funnelConversion}
            </strong>
          </span>
        </div>

        <ol className="funnel">
          {data.funnel.map((stage, index) => (
            <li className="funnel__stage" key={stage.step}>
              <div className="funnel__head">
                <span className="t-label-sm upper muted">{stage.step}</span>
                <span className="t-label-md" style={{ color: 'var(--primary)' }}>
                  {stage.percent}%
                </span>
              </div>
              <div className="t-body-md" style={{ fontWeight: 600 }}>
                {stage.title}
              </div>
              <div className="t-metric" style={{ fontSize: 20, color: 'var(--primary)' }}>
                {stage.count}
              </div>
              <div className="t-body-sm muted">{stage.caption}</div>
              <div className="progress" style={{ marginTop: 8 }}>
                <span
                  className="progress__fill progress__fill--brand"
                  style={{ width: `${stage.percent}%` }}
                />
              </div>
              {stage.handoff ? (
                <div className="funnel__handoff t-label-sm muted">
                  {stage.handoff}
                  <span className="icon" style={{ fontSize: 14 }} aria-hidden="true">
                    arrow_forward
                  </span>
                </div>
              ) : (
                <div className="funnel__handoff t-label-sm" style={{ color: 'var(--success)' }}>
                  Net: {data.funnelConversion} Overall
                  <span className="icon" style={{ fontSize: 14 }} aria-hidden="true">
                    done_all
                  </span>
                </div>
              )}
              {index < data.funnel.length - 1 && (
                <span className="funnel__arrow icon" aria-hidden="true">
                  chevron_right
                </span>
              )}
            </li>
          ))}
        </ol>
      </section>

      <section className="detailsplit">
        <RatePanel
          title="Matching Performance"
          subtitle="Time-to-accept metrics across available field couriers"
          headline={data.matchingHeadline}
          headlineCaption="avg matching time"
          rows={data.matchingRows}
          note={data.matchingNote}
          noteIcon="info"
        />
        <RatePanel
          title="Pickup Performance"
          subtitle="Transit execution and scheduled window adherence"
          headline={data.pickupHeadline}
          headlineCaption="avg transit & pickup"
          rows={data.pickupRows}
          note={data.pickupNote}
          noteIcon="verified_user"
        />
      </section>

      <section className="detailsplit">
        <article className="card">
          <div className="section-head">
            <div>
              <h2 className="t-headline-sm" style={{ margin: 0 }}>
                Operational Intervention
              </h2>
              <span className="t-body-sm muted">
                Breakdown of manual resolution workflows and fail-safes
              </span>
            </div>
            <span className="chip t-label-sm" style={{
              background: 'var(--secondary-container)',
              color: 'var(--primary)',
            }}>
              Desk Active
            </span>
          </div>

          <div className="statgrid">
            {data.interventions.map((stat) => (
              <div className="statgrid__cell" key={stat.label}>
                <span className="t-label-sm upper muted">{stat.label}</span>
                <span
                  className="t-metric"
                  style={{
                    fontSize: 24,
                    color:
                      stat.tone === 'critical' ? 'var(--error)' : 'var(--primary)',
                  }}
                >
                  {stat.value}
                </span>
                <span className="t-body-sm muted">{stat.caption}</span>
              </div>
            ))}
          </div>

          <div className="alertcard alertcard--neutral">
            <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
              alt_route
            </span>
            <div className="t-body-sm">{data.interventionNote}</div>
          </div>
        </article>

        <article className="card">
          <div className="section-head">
            <div>
              <h2 className="t-headline-sm" style={{ margin: 0 }}>
                Top Operational Bottlenecks
              </h2>
              <span className="t-body-sm muted">
                Ranked operational friction points identified by operations desk
              </span>
            </div>
            <span className="t-label-sm muted">30-day tally</span>
          </div>

          <ol className="ranked">
            {data.bottlenecks.map((item) => (
              <li className="ranked__row" key={item.rank}>
                <span className="ranked__num t-label-md">{item.rank}</span>
                <div className="ranked__body">
                  <div className="t-body-md" style={{ fontWeight: 600 }}>
                    {item.title}
                  </div>
                  <div className="t-body-sm muted">{item.caption}</div>
                  <div className="progress" style={{ marginTop: 6 }}>
                    <span
                      className="progress__fill progress__fill--warn"
                      style={{ width: `${item.percent}%` }}
                    />
                  </div>
                </div>
                <span className="t-metric ranked__pct" style={{ fontSize: 15 }}>
                  {item.percent}%
                </span>
              </li>
            ))}
          </ol>
        </article>
      </section>

      <section className="sectorsplit">
        <article className="card">
          <div className="section-head">
            <div>
              <h2 className="t-headline-sm" style={{ margin: 0 }}>
                Location Performance
              </h2>
              <span className="t-body-sm muted">
                Sector breakdown of volumetric completion and matching lag
              </span>
            </div>
            <span className="t-label-sm muted">4 active urban sectors</span>
          </div>

          <div className="tablewrap">
            <table className="dtable">
              <thead>
                <tr>
                  <th scope="col">Area</th>
                  <th scope="col">Rescues</th>
                  <th scope="col">Success Rate</th>
                  <th scope="col">Avg Match Time</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {data.sectors.map((row) => (
                  <tr key={row.area}>
                    <td className="t-body-md" style={{ fontWeight: 600 }}>
                      {row.area}
                    </td>
                    <td className="t-body-md">{row.rescues}</td>
                    <td className="t-body-md">{row.successRate}</td>
                    <td className="t-body-md">{row.avgMatch}</td>
                    <td>
                      <span
                        className="dtable__state t-label-sm"
                        style={{ color: STATUS_TONE[row.status] }}
                      >
                        <span className="dot" style={{ background: STATUS_TONE[row.status] }} />
                        {row.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="queue__foot t-body-sm">
            <span>{data.sectorNote}</span>
            {/* CSV export needs the Phase 14 reporting endpoint. */}
            <button className="linkbtn t-label-md" type="button" disabled>
              Export sector CSV →
            </button>
          </div>
        </article>

        <article className="card">
          <div className="section-head">
            <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                visibility
              </span>
              Operational observation
            </h2>
          </div>

          <div style={{ padding: 16 }}>
            <div className="t-body-lg" style={{ fontWeight: 600 }}>
              {data.insightTitle}
            </div>
            {data.insightBody.map((paragraph) => (
              <p className="t-body-sm muted" key={paragraph} style={{ margin: '8px 0 0' }}>
                {paragraph}
              </p>
            ))}
          </div>

          <div className="alertcard alertcard--good">
            <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
              notification_important
            </span>
            <div>
              <div className="t-body-sm">{data.recommendation}</div>
              <button
                className="linkbtn t-label-md"
                type="button"
                onClick={() => navigate('/live-rescues')}
              >
                Review live coverage →
              </button>
            </div>
          </div>
        </article>
      </section>
    </ConsoleLayout>
  );
}

function RatePanel({
  title,
  subtitle,
  headline,
  headlineCaption,
  rows,
  note,
  noteIcon,
}: {
  title: string;
  subtitle: string;
  headline: string;
  headlineCaption: string;
  rows: RateRow[];
  note: string;
  noteIcon: string;
}) {
  return (
    <article className="card">
      <div className="section-head">
        <div>
          <h2 className="t-headline-sm" style={{ margin: 0 }}>
            {title}
          </h2>
          <span className="t-body-sm muted">{subtitle}</span>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div className="t-metric" style={{ fontSize: 22, color: 'var(--primary)' }}>
            {headline}
          </div>
          <div className="t-label-sm muted">{headlineCaption}</div>
        </div>
      </div>

      <div className="rates">
        {rows.map((row) => (
          <div className="rates__row" key={row.label}>
            <div className="rates__head">
              <span className="t-body-md">{row.label}</span>
              <span className="t-metric" style={{ fontSize: 14 }}>
                {row.percent}%
              </span>
            </div>
            <div className="progress">
              <span
                className={`progress__fill ${
                  row.positive ? 'progress__fill--brand' : 'progress__fill--warn'
                }`}
                style={{ width: `${row.percent}%` }}
              />
            </div>
            <div className="t-body-sm muted">{row.caption}</div>
          </div>
        ))}
      </div>

      <div className="alertcard alertcard--neutral">
        <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
          {noteIcon}
        </span>
        <div className="t-body-sm">{note}</div>
      </div>
    </article>
  );
}
