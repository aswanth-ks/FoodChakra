import { useNavigate } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import { SAMPLE_ZERO_WASTE_OVERVIEW } from './data/sampleZeroWaste';
import {
  TIER_LABEL,
  formatRemaining,
  type FallbackCase,
  type ZeroWasteOverview,
} from './data/zeroWasteTypes';
import { TierChip } from './components/ZeroWasteChrome';
import { TIER_COLOR } from './data/tierStyle';
import { SAMPLE_NETWORK_STATUS } from '../rescues/data/sampleRescues';
import type { NetworkStatus } from '../rescues/data/rescueTypes';

const SEVERITY_CLASS: Record<FallbackCase['severity'], string> = {
  critical: ' qitem--critical',
  attention: ' qitem--attention',
  steady: '',
};

const SEVERITY_COLOR: Record<FallbackCase['severity'], string> = {
  critical: 'var(--error)',
  attention: 'var(--warning-deep)',
  steady: 'var(--on-surface-variant)',
};

/**
 * "FoodLoop Zero-Waste Network Console - Overview".
 *
 * The fallback tier's dashboard. Every case here arrived because the human
 * tier failed, so this page is read as a failure ledger rather than a success
 * one: the headline number is what was kept out of landfill, and the number
 * next to it is what was not.
 *
 * The hierarchy panel is the page's centre of gravity. It is ordered
 * best-to-worst and always rendered in that order, because the order is the
 * food-use hierarchy that waste regulation is built around - not a sort the
 * operator should be able to change.
 *
 * **No Stitch design reached this session.** A design exists for Fallback
 * Opportunity (`a75b3478a61043db95d66ff928a1c838`) but the Stitch MCP server
 * is not available here, so all four Zero-Waste pages are built from the
 * console's own tokens and primitives, like Console Sign In and the
 * Management pages. Reconcile against the mock when Stitch is reachable.
 *
 * **Nothing here dispatches.** Routing a case sends a real vehicle to a real
 * address; every such control is disabled pending the Phase 14 console API.
 */
export default function ZeroWasteOverviewPage({
  data = SAMPLE_ZERO_WASTE_OVERVIEW,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: ZeroWasteOverview;
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();

  const recoveredKg = data.hierarchy
    .filter((row) => row.tier !== 'landfill')
    .reduce((sum, row) => sum + row.kg, 0);

  return (
    <ConsoleLayout
      title="Zero-Waste Network"
      subtitle={`${data.totals.openCases} open cases`}
      statusStrip={
        <ConsoleStatusStrip
          activeRescues={status.activeRescues}
          needIntervention={data.totals.openCases}
          version={status.consoleVersion}
        />
      }
    >
      <nav className="crumbs t-body-sm" aria-label="Breadcrumb">
        <span className="muted">Operations Core</span>
        <span aria-hidden="true">&rsaquo;</span>
        <span className="muted">Zero-Waste Network</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">Zero-Waste Network</h1>
          <p className="t-body-md">
            The fallback tier. Surplus reaches this page only after the human
            tier has failed &mdash; the job here is to keep it out of landfill
            by routing it down the recovery hierarchy.
          </p>
        </div>
        <div className="intro__actions">
          <span className="pill t-label-sm">
            <span
              className="dot dot--pulse"
              style={{ background: 'var(--success)' }}
            />
            {data.totals.diversionRate}% diverted
          </span>
          <span className="t-label-sm muted">{data.window}</span>
        </div>
      </section>


      <section className="kpis" aria-label="Diversion totals">
        <TierKpi
          label="Diverted"
          icon="recycling"
          value={`${data.totals.divertedKg.toLocaleString()} kg`}
          caption={`Kept out of landfill - ${data.window.toLowerCase()}`}
          color="var(--success)"
        />
        <TierKpi
          label="Reached Landfill"
          icon="delete"
          value={`${data.totals.landfillKg} kg`}
          caption="Every kilogram here is a failure"
          color="var(--error)"
        />
        <TierKpi
          label="Open Cases"
          icon="pending_actions"
          value={`${data.totals.openCases}`}
          caption="Awaiting a routing decision"
          color="var(--warning-deep)"
        />
        <TierKpi
          label="CO2e Avoided"
          icon="eco"
          value={data.totals.co2Avoided}
          caption={`${data.totals.activePartners} recovery partners active`}
        />
      </section>

      <section className="sectorsplit">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          {/* The hierarchy: always best-to-worst, never re-sortable. */}
          <div className="card">
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                  Recovery Hierarchy
                </h2>
                <span className="t-body-sm muted">
                  Where network volume ended up, best tier first
                </span>
              </div>
              <span className="t-label-sm muted">
                {recoveredKg.toLocaleString()} kg recovered
              </span>
            </div>

            <div className="rates">
              {data.hierarchy.map((row) => (
                <div className="rates__row" key={row.tier}>
                  <div className="rates__head">
                    <span
                      style={{ display: 'flex', alignItems: 'center', gap: 8 }}
                    >
                      <TierChip tier={row.tier} />
                      <span className="t-label-sm muted">
                        {row.consignments} consignments
                      </span>
                    </span>
                    <span className="t-body-sm" style={{ fontWeight: 600 }}>
                      {row.kg.toLocaleString()} kg &middot; {row.share}%
                    </span>
                  </div>
                  <div className="progress">
                    <span
                      className="progress__fill"
                      style={{
                        width: `${row.share}%`,
                        background: TIER_COLOR[row.tier],
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>

            <p className="levels__note t-body-sm">
              The order is the food-use hierarchy, not a preference. Routing
              must exhaust every rung before dropping to the next.
            </p>
          </div>

          {/* Open cases. */}
          <div className="card">
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                  Open Fallback Cases
                </h2>
                <span className="t-body-sm muted">
                  Surplus held and waiting on a destination
                </span>
              </div>
              <span
                className="chip t-label-sm"
                style={{
                  background: 'var(--error-container)',
                  color: 'var(--on-error-container)',
                }}
              >
                {data.cases.length} open
              </span>
            </div>

            <div className="queue__list">
              {data.cases.map((entry) => (
                <button
                  key={entry.id}
                  type="button"
                  className={`qitem${SEVERITY_CLASS[entry.severity]}`}
                  style={{
                    width: '100%',
                    textAlign: 'left',
                    background: 'none',
                    cursor: 'pointer',
                  }}
                  onClick={() => navigate(`/zero-waste/fallback/${entry.id}`)}
                >
                  <div className="qitem__head">
                    <span className="t-body-md" style={{ fontWeight: 600 }}>
                      {entry.surplus}
                    </span>
                    <span
                      className="t-label-sm"
                      style={{
                        color: SEVERITY_COLOR[entry.severity],
                        fontWeight: 600,
                      }}
                    >
                      {formatRemaining(entry.minutesLeft)}
                    </span>
                  </div>

                  <div className="qitem__meta t-body-sm muted">
                    {entry.id} &middot; from rescue #{entry.rescueId} &middot;{' '}
                    {entry.partner} &middot; {entry.zone} &middot; {entry.kg} kg
                  </div>

                  <div className="t-body-sm">{entry.reason}</div>

                  <div className="qitem__foot">
                    <span
                      style={{ display: 'flex', alignItems: 'center', gap: 6 }}
                    >
                      <span className="t-label-sm muted">Proposed</span>
                      <TierChip tier={entry.proposedTier} short />
                    </span>
                    <span className="linkbtn t-label-md">Open case &#8599;</span>
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Diversion feed. */}
        <aside className="card" aria-label="Recent diversions">
          <div className="section-head">
            <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
              Recent Diversions
            </h2>
            <span className="t-label-sm muted dtable__state">
              <span
                className="dot dot--pulse"
                style={{ background: 'var(--success)' }}
              />
              Live
            </span>
          </div>

          <ol className="audit">
            {data.events.map((entry) => (
              <li className="audit__row" key={`${entry.when}-${entry.title}`}>
                <span className="audit__rail" aria-hidden="true">
                  <span
                    className="audit__dot"
                    style={{ background: TIER_COLOR[entry.tier] }}
                  />
                </span>
                <div className="audit__body">
                  <div className="audit__title">
                    <span className="t-body-md" style={{ fontWeight: 600 }}>
                      {entry.title}
                    </span>
                    <span className="t-label-sm muted">{entry.when}</span>
                  </div>
                  <div className="t-body-sm muted">{entry.detail}</div>
                  <div className="t-label-sm" style={{ color: TIER_COLOR[entry.tier] }}>
                    {entry.kg} kg &middot; {TIER_LABEL[entry.tier]}
                  </div>
                </div>
              </li>
            ))}
          </ol>

          <div className="controls" style={{ paddingTop: 0 }}>
            <button
              className="btn btn--quiet btn--block"
              type="button"
              onClick={() => navigate('/zero-waste/routing')}
            >
              <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                alt_route
              </span>
              Review routing rules
            </button>
            {/* A broadcast reaches real recovery partners. */}
            <button
              className="btn btn--quiet btn--block"
              type="button"
              disabled
              title="Broadcasting to partners needs the Phase 14 console API"
            >
              Broadcast open cases to partners
            </button>
          </div>
        </aside>
      </section>
    </ConsoleLayout>
  );
}

function TierKpi({
  label,
  icon,
  value,
  caption,
  color = 'var(--on-surface)',
}: {
  label: string;
  icon: string;
  value: string;
  caption: string;
  color?: string;
}) {
  return (
    <article className="card kpi">
      <div className="kpi__head">
        <span className="t-label-sm upper muted">{label}</span>
        <span className="icon muted" style={{ fontSize: 18 }} aria-hidden="true">
          {icon}
        </span>
      </div>
      <div className="kpi__value">
        <span
          className="t-metric"
          style={{ fontSize: 30, lineHeight: '38px', color, fontWeight: 700 }}
        >
          {value}
        </span>
      </div>
      <div className="kpi__foot t-body-sm truncate">{caption}</div>
    </article>
  );
}
