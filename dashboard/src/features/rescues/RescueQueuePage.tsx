import { useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import { SAMPLE_QUEUE } from './data/sampleQueue';
import { SAMPLE_NETWORK_STATUS } from './data/sampleRescues';
import { SEVERITY_COLOR, SEVERITY_LABEL } from './data/severity';
import type { QueueData, QueueRow } from './data/queueTypes';
import type { NetworkStatus } from './data/rescueTypes';

/** Which filter chips map onto which rows. */
const FILTER_MATCH: Record<string, (row: QueueRow) => boolean> = {
  all: () => true,
  critical: (row) => row.priority === 'critical',
  attention: (row) => row.priority === 'attention',
  searching: (row) => row.state.toLowerCase().includes('no rescuer'),
  matched: (row) => row.state.toLowerCase().includes('matched'),
  approaching: (row) => row.state.toLowerCase().includes('approaching'),
  completed: (row) => row.priority === 'completed',
};

/**
 * "FoodLoop Rescue Operations Console — Rescue Queue".
 *
 * Faithful translation of the Stitch design
 * (screen `5f3fede2b5f74d57834db003fcfc2d66`).
 *
 * The worklist: every active opportunity as a table, with the selected one
 * inspected beside it and routes out to the three screens that act on it.
 *
 * **Design divergence:** the mock redraws the sidebar and status bar; both
 * come from the shared console layout, as on the other console pages.
 */
export default function RescueQueuePage({
  data = SAMPLE_QUEUE,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: QueueData;
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();

  const [filter, setFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(
    data.inspection.id,
  );

  const rows = useMemo(() => {
    const query = search.trim().toLowerCase();
    const matches = FILTER_MATCH[filter] ?? FILTER_MATCH.all;
    return data.rows.filter(
      (row) =>
        matches(row) &&
        (query.length === 0 ||
          row.id.toLowerCase().includes(query) ||
          row.restaurant.toLowerCase().includes(query) ||
          row.quantityLabel.toLowerCase().includes(query)),
    );
  }, [data.rows, filter, search]);

  const inspection = data.inspection;
  const panelOpen = selectedId !== null;

  return (
    <ConsoleLayout
      title="Rescue Queue"
      subtitle="Prioritised active opportunities"
      statusStrip={
        <ConsoleStatusStrip
          activeRescues={status.activeRescues}
          needIntervention={status.needIntervention}
          pickupsApproaching={status.pickupsApproaching}
          version={status.consoleVersion}
        />
      }
    >
      <nav className="crumbs t-body-sm" aria-label="Breadcrumb">
        <Link to="/overview">Rescue Operations</Link>
        <span aria-hidden="true">›</span>
        <span className="muted">Rescue Queue</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">Rescue Queue</h1>
          <p className="t-body-md">
            Review active rescue opportunities and prioritize the ones
            requiring attention.
          </p>
        </div>
        <div className="intro__actions">
          <span className="pill t-label-sm">
            <span className="dot dot--pulse" style={{ background: 'var(--success)' }} />
            {data.totalActive} active
          </span>
          <span className="t-label-sm muted">Updated just now</span>
        </div>
      </section>

      <section className="kpis" aria-label="Queue summary">
        {data.kpis.map((kpi) => {
          const color =
            kpi.tone === 'critical'
              ? 'var(--error)'
              : kpi.tone === 'warning'
                ? 'var(--warning-deep)'
                : 'var(--primary)';
          return (
            <article className="card kpi" key={kpi.label}>
              <div className="kpi__head">
                <span className="t-label-sm upper muted">{kpi.label}</span>
                <span className="icon muted" style={{ fontSize: 18 }} aria-hidden="true">
                  {kpi.icon}
                </span>
              </div>
              <div className="kpi__value">
                <span
                  className="t-metric"
                  style={{ fontSize: 32, lineHeight: '40px', color, fontWeight: 700 }}
                >
                  {kpi.value}
                </span>
              </div>
              <div className="kpi__foot t-body-sm truncate">{kpi.caption}</div>
            </article>
          );
        })}
      </section>

      <section className="card queuebar">
        <div className="topbar__search" style={{ maxWidth: 320 }}>
          <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
            search
          </span>
          <input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search rescues, partners, or IDs"
            aria-label="Search the rescue queue"
          />
          <span className="kbd t-label-sm">⌘K</span>
        </div>

        <div className="pillrow" role="group" aria-label="Queue filter">
          {data.filters.map((entry) => (
            <button
              key={entry.id}
              type="button"
              aria-pressed={filter === entry.id}
              className={`filterpill t-label-sm${
                filter === entry.id ? ' filterpill--on' : ''
              }`}
              onClick={() => setFilter(entry.id)}
            >
              {entry.label}
              {entry.count !== null && ` (${entry.count})`}
            </button>
          ))}
        </div>

        <span className="t-label-sm muted queuebar__sort">
          Priority sorted
          <span className="icon" style={{ fontSize: 14 }} aria-hidden="true">
            arrow_downward
          </span>
        </span>
      </section>

      <section className={`queuesplit${panelOpen ? '' : ' queuesplit--wide'}`}>
        <div className="card">
          <div className="tablewrap">
            <table className="dtable">
              <thead>
                <tr>
                  <th scope="col">Priority</th>
                  <th scope="col">Rescue</th>
                  <th scope="col">Restaurant</th>
                  <th scope="col">Current State</th>
                  <th scope="col">Time Remaining</th>
                  <th scope="col">
                    <span className="visually-hidden">Action</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.length === 0 && (
                  <tr>
                    <td colSpan={6} className="t-body-sm muted dtable__empty">
                      No opportunities match this filter.
                    </td>
                  </tr>
                )}

                {rows.map((row) => {
                  const selected = row.id === selectedId;
                  const color = SEVERITY_COLOR[row.priority];
                  return (
                    <tr
                      key={row.id}
                      className={selected ? 'dtable__row--on' : undefined}
                      onClick={() => setSelectedId(row.id)}
                    >
                      <td>
                        <span
                          className="chip t-label-sm"
                          style={{
                            background:
                              row.priority === 'critical'
                                ? 'var(--error-container)'
                                : row.priority === 'attention'
                                  ? 'var(--warning-bg)'
                                  : 'var(--surface-container-low)',
                            color,
                            border:
                              row.priority === 'attention'
                                ? '1px solid var(--warning-border)'
                                : undefined,
                          }}
                        >
                          {SEVERITY_LABEL[row.priority].toUpperCase()}
                        </span>
                      </td>
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
                          {row.branch}
                        </span>
                      </td>
                      <td>
                        <span className="dtable__state t-body-sm">
                          <span
                            className="icon"
                            style={{ fontSize: 15, color }}
                            aria-hidden="true"
                          >
                            {row.stateIcon}
                          </span>
                          {row.state}
                        </span>
                      </td>
                      <td>
                        {row.minutesRemaining === null ? (
                          <span className="t-label-sm muted">Done</span>
                        ) : (
                          <span
                            className="dtable__state t-metric"
                            style={{ fontSize: 13, color }}
                          >
                            <span
                              className="icon"
                              style={{ fontSize: 14 }}
                              aria-hidden="true"
                            >
                              {row.priority === 'critical' ? 'timer' : 'schedule'}
                            </span>
                            {row.minutesRemaining} min
                          </span>
                        )}
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <button
                          className="btn btn--quiet"
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            navigate(`/live-rescues/${row.id}`);
                          }}
                        >
                          {row.actionLabel}
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <div className="queue__foot t-body-sm">
            <span>
              Showing {rows.length} of {data.totalActive} active opportunities
            </span>
            <span className="pager">
              {/* Paging needs the Phase 14 console API. */}
              <button className="btn btn--quiet" type="button" disabled>
                Prev
              </button>
              <span className="t-label-sm muted">
                Page {data.page} of {data.pageCount}
              </span>
              <button className="btn btn--quiet" type="button" disabled>
                Next
              </button>
            </span>
          </div>
        </div>

        {panelOpen && (
          <aside className="card" aria-label="Selected opportunity">
            <div className="section-head">
              <div>
                <h2 className="t-headline-sm" style={{ margin: 0 }}>
                  Selected Opportunity
                </h2>
                <span className="t-body-sm muted">{inspection.id}</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span
                  className="chip t-label-sm"
                  style={{
                    background: 'var(--error-container)',
                    color: 'var(--on-error-container)',
                  }}
                >
                  CRITICAL
                </span>
                <button
                  className="iconbtn"
                  type="button"
                  onClick={() => setSelectedId(null)}
                  aria-label="Close inspection panel"
                >
                  <span className="icon" style={{ fontSize: 18 }}>
                    close
                  </span>
                </button>
              </div>
            </div>

            <div className="inspect">
              <InspectRow icon="storefront" title={inspection.restaurant}>
                {inspection.address}
              </InspectRow>
              <InspectRow
                icon="acute"
                title={inspection.pickupWindow}
                accent={`${inspection.minutesRemaining} min left`}
              >
                {inspection.windowNote}
              </InspectRow>
              <InspectRow icon="lunch_dining" title={inspection.foodSummary}>
                {inspection.foodNote}
              </InspectRow>
            </div>

            <div className="alertcard alertcard--error" style={{ margin: '0 16px 16px' }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                warning
              </span>
              <div>
                <div className="t-body-md" style={{ fontWeight: 600 }}>
                  {inspection.statusTitle}
                </div>
                <div className="t-body-sm">{inspection.statusBody}</div>
              </div>
            </div>

            <div className="controls" style={{ paddingTop: 0 }}>
              <button
                className="btn btn--primary btn--block"
                type="button"
                onClick={() => navigate(`/live-rescues/${inspection.id}`)}
              >
                Open Rescue Opportunity
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  arrow_forward
                </span>
              </button>
              <button
                className="btn btn--quiet btn--block"
                type="button"
                onClick={() => navigate('/escalations')}
              >
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  trending_up
                </span>
                Open Smart Escalation
              </button>
              <button
                className="btn btn--quiet btn--block"
                type="button"
                onClick={() =>
                  navigate(`/live-rescues/${inspection.id}/coverage`)
                }
              >
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  map
                </span>
                View Dynamic Coverage
              </button>
            </div>

            <div className="alertcard alertcard--good" style={{ marginTop: 0 }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                hub
              </span>
              <div>
                <div className="t-body-md" style={{ fontWeight: 600 }}>
                  {inspection.handoverTitle}
                </div>
                <div className="t-body-sm">{inspection.handoverBody}</div>
                {/* The Zero-Waste Network console page is not built yet. */}
                <button
                  className="linkbtn t-label-md"
                  type="button"
                  disabled
                  title="Zero-Waste Network — not built yet"
                >
                  Open Zero-Waste Network →
                </button>
              </div>
            </div>
          </aside>
        )}
      </section>
    </ConsoleLayout>
  );
}

function InspectRow({
  icon,
  title,
  accent,
  children,
}: {
  icon: string;
  title: string;
  accent?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="inspect__row">
      <span className="icon muted" style={{ fontSize: 18 }} aria-hidden="true">
        {icon}
      </span>
      <div style={{ minWidth: 0 }}>
        <div className="inspect__title">
          <span className="t-body-md" style={{ fontWeight: 600 }}>
            {title}
          </span>
          {accent && (
            <span className="t-label-sm" style={{ color: 'var(--error)' }}>
              {accent}
            </span>
          )}
        </div>
        <div className="t-body-sm muted">{children}</div>
      </div>
    </div>
  );
}
