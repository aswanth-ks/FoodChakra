import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import { SAMPLE_RECOVERY_HISTORY } from './data/sampleRecoveryHistory';
import {
  DAY_LABEL,
  OUTCOME_LABEL,
  type DayBucket,
  type RecoveryHistory,
  type RecoveryOutcome,
} from './data/recoveryHistoryTypes';
import { SAMPLE_NETWORK_STATUS } from '../rescues/data/sampleRescues';
import type { NetworkStatus } from '../rescues/data/rescueTypes';

const OUTCOME_STYLE: Record<RecoveryOutcome, { bg: string; fg: string }> = {
  completed: { bg: 'var(--primary-fixed)', fg: 'var(--on-primary-fixed)' },
  cancelled: { bg: 'var(--surface-container)', fg: 'var(--on-surface-variant)' },
  failed: { bg: 'var(--error-container)', fg: 'var(--on-error-container)' },
};

const OUTCOME_DOT: Record<RecoveryOutcome, string> = {
  completed: 'var(--success)',
  cancelled: 'var(--on-surface-variant)',
  failed: 'var(--error)',
};

type OutcomeFilter = 'all' | RecoveryOutcome;
type DateFilter = 'all' | DayBucket;

/**
 * "FoodLoop Zero-Waste Network Console - Recovery History".
 *
 * Faithful translation of the Stitch design
 * (screen `0cfa0a7d733d45f3b5142b0a442db1f8`): the title and its quoted
 * subtitle, the toolbar with search, the All / Completed / Cancelled / Failed
 * filters, the Date control and the Newest sort, the seven-column table, and
 * the Recovery Details panel with its Status Notes and View Partner action.
 *
 * The design draws every toolbar control, so all of them work: search, the
 * status filters, the date bucket and the sort direction all filter and order
 * the table live. A row of controls that only *looked* filterable would be the
 * worst outcome on a page whose entire job is finding one past record.
 *
 * This is the tier's **record**, so like the Activity Log it is read-only by
 * design: a completed recovery is evidence of what happened to real food, and
 * there is deliberately no edit, no delete and no re-run on this page.
 *
 * **Design divergences:** the mock is drawn on the mobile brand surface and
 * redraws its own sidebar; this uses the console palette and the shared
 * `ConsoleLayout`, as every console page translated from a Mobile Design
 * System screen has. The mock's own sidebar also lists destinations this
 * console does not have yet (Active Recoveries, Handover, Partner
 * Availability), which are separate screens and not in scope here.
 */
export default function RecoveryHistoryPage({
  data = SAMPLE_RECOVERY_HISTORY,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: RecoveryHistory;
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();

  const [outcome, setOutcome] = useState<OutcomeFilter>('all');
  const [day, setDay] = useState<DateFilter>('all');
  const [search, setSearch] = useState('');
  const [newestFirst, setNewestFirst] = useState(true);
  const [selectedId, setSelectedId] = useState<string | null>(
    data.records[0]?.id ?? null,
  );

  const records = useMemo(() => {
    const query = search.trim().toLowerCase();
    const filtered = data.records.filter((row) => {
      const matchesOutcome = outcome === 'all' || row.outcome === outcome;
      const matchesDay = day === 'all' || row.day === day;
      const matchesQuery =
        query.length === 0 ||
        row.id.toLowerCase().includes(query) ||
        row.source.toLowerCase().includes(query) ||
        row.partner.toLowerCase().includes(query) ||
        row.type.toLowerCase().includes(query);
      return matchesOutcome && matchesDay && matchesQuery;
    });

    return filtered.sort((a, b) =>
      newestFirst ? b.at.localeCompare(a.at) : a.at.localeCompare(b.at),
    );
  }, [data.records, outcome, day, search, newestFirst]);

  const selected =
    data.records.find((row) => row.id === selectedId) ?? null;

  const counts: Record<OutcomeFilter, number> = {
    all: data.records.length,
    completed: data.records.filter((r) => r.outcome === 'completed').length,
    cancelled: data.records.filter((r) => r.outcome === 'cancelled').length,
    failed: data.records.filter((r) => r.outcome === 'failed').length,
  };

  const tabs: OutcomeFilter[] = ['all', 'completed', 'cancelled', 'failed'];

  return (
    <ConsoleLayout
      title="Recovery History"
      subtitle={`${data.records.length} records`}
      statusStrip={
        <ConsoleStatusStrip
          activeRescues={status.activeRescues}
          needIntervention={counts.failed}
          version={status.consoleVersion}
        />
      }
    >
      <nav className="crumbs t-body-sm" aria-label="Breadcrumb">
        <span className="muted">Zero-Waste Network</span>
        <span aria-hidden="true">&rsaquo;</span>
        <span className="muted">Recovery History</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">Recovery History</h1>
          <p className="t-body-md">
            View completed and past alternative recovery records.
          </p>
        </div>
        <div className="intro__actions">
          <span className="pill t-label-sm">
            <span
              className="dot"
              style={{ background: 'var(--success)' }}
            />
            {counts.completed} completed
          </span>
          <span className="t-label-sm muted">Updated just now</span>
        </div>
      </section>

      {/* The design's toolbar: search, status filters, date, sort. */}
      <section className="card queuebar">
        <div className="topbar__search" style={{ maxWidth: 300 }}>
          <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
            search
          </span>
          <input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search recovery..."
            aria-label="Search recovery records"
            style={{ paddingRight: 12 }}
          />
        </div>

        <div className="segmented" role="group" aria-label="Recovery outcome">
          {tabs.map((entry) => (
            <button
              key={entry}
              type="button"
              aria-pressed={outcome === entry}
              className={`segmented__btn t-label-md${
                outcome === entry ? ' segmented__btn--on' : ''
              }`}
              onClick={() => setOutcome(entry)}
            >
              {entry === 'all' ? 'All' : OUTCOME_LABEL[entry]} {counts[entry]}
            </button>
          ))}
        </div>

        <label className="visually-hidden" htmlFor="history-date">
          Filter by date
        </label>
        <select
          id="history-date"
          className="select"
          style={{ height: 36, marginLeft: 'auto' }}
          value={day}
          onChange={(event) => setDay(event.target.value as DateFilter)}
        >
          <option value="all">Any date</option>
          <option value="today">{DAY_LABEL.today}</option>
          <option value="yesterday">{DAY_LABEL.yesterday}</option>
          <option value="earlier">{DAY_LABEL.earlier}</option>
        </select>

        <span
          className="t-label-sm muted"
          style={{ display: 'flex', alignItems: 'center', gap: 8 }}
        >
          Sort:
          <button
            className="btn btn--quiet"
            type="button"
            onClick={() => setNewestFirst((on) => !on)}
            aria-label={`Sorted ${
              newestFirst ? 'newest first' : 'oldest first'
            }. Change order.`}
          >
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              sort
            </span>
            {newestFirst ? 'Newest' : 'Oldest'}
          </button>
        </span>
      </section>

      <section className={`queuesplit${selected ? '' : ' queuesplit--wide'}`}>
        <div className="card">
          <div className="tablewrap">
            <table className="dtable">
              <thead>
                <tr>
                  <th scope="col">Recovery</th>
                  <th scope="col">Source</th>
                  <th scope="col">Recovery Partner</th>
                  <th scope="col">Type</th>
                  <th scope="col">Status</th>
                  <th scope="col">Completed</th>
                  <th scope="col">
                    <span className="visually-hidden">Action</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {records.length === 0 && (
                  <tr>
                    <td colSpan={7} className="t-body-sm muted dtable__empty">
                      No recovery records match this filter.
                    </td>
                  </tr>
                )}

                {records.map((row) => (
                  <tr
                    key={row.id}
                    className={
                      row.id === selectedId ? 'dtable__row--on' : undefined
                    }
                    onClick={() => setSelectedId(row.id)}
                  >
                    <td className="t-body-md" style={{ fontWeight: 600 }}>
                      {row.id}
                    </td>
                    <td className="t-body-sm">{row.source}</td>
                    <td className="t-body-sm">{row.partner}</td>
                    <td className="t-body-sm">{row.type}</td>
                    <td>
                      <span
                        className="chip t-label-sm upper"
                        style={{
                          background: OUTCOME_STYLE[row.outcome].bg,
                          color: OUTCOME_STYLE[row.outcome].fg,
                        }}
                      >
                        <span
                          className="dot"
                          style={{ background: OUTCOME_DOT[row.outcome] }}
                        />
                        {OUTCOME_LABEL[row.outcome]}
                      </span>
                    </td>
                    <td className="t-body-sm muted">{row.completedLabel}</td>
                    <td style={{ textAlign: 'right' }}>
                      <button
                        className="btn btn--quiet"
                        type="button"
                        onClick={(event) => {
                          event.stopPropagation();
                          setSelectedId(row.id);
                        }}
                      >
                        View
                        <span
                          className="icon"
                          style={{ fontSize: 15 }}
                          aria-hidden="true"
                        >
                          arrow_forward
                        </span>
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="queue__foot t-body-sm">
            <span>
              Showing {records.length} of {data.records.length} records
            </span>
            <span className="pager">
              {/* Paging the full history needs the Phase 14 console API. */}
              <button className="btn btn--quiet" type="button" disabled>
                Load older records
              </button>
            </span>
          </div>
        </div>

        {selected && (
          <aside className="card" aria-label={`Recovery ${selected.id}`}>
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <h2 className="t-headline-sm" style={{ margin: 0 }}>
                  Recovery Details
                </h2>
                <span className="t-body-sm muted">
                  {selected.id} &middot; {OUTCOME_LABEL[selected.outcome]}
                </span>
              </div>
              <button
                className="iconbtn"
                type="button"
                onClick={() => setSelectedId(null)}
                aria-label="Close recovery details"
              >
                <span className="icon" style={{ fontSize: 18 }}>
                  close
                </span>
              </button>
            </div>

            <dl className="factlist">
              <div className="factlist__row">
                <dt className="t-body-sm muted">Source</dt>
                <dd className="t-body-md">{selected.source}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Food</dt>
                <dd className="t-body-md">{selected.detail.food}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Recovery Partner</dt>
                <dd className="t-body-md">{selected.partner}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Recovery Type</dt>
                <dd className="t-body-md">{selected.type}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Route</dt>
                <dd className="t-body-md">{selected.detail.route}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Handover</dt>
                <dd className="t-body-md">{selected.detail.handover}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Completed</dt>
                <dd className="t-body-md">{selected.completedLabel}</dd>
              </div>
            </dl>

            <div className="section-head">
              <h3 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                Status Notes
              </h3>
            </div>

            <div
              className={`alertcard ${
                selected.outcome === 'completed'
                  ? 'alertcard--good'
                  : selected.outcome === 'failed'
                    ? 'alertcard--error'
                    : 'alertcard--neutral'
              }`}
            >
              <span className="t-body-sm">{selected.detail.notes}</span>
            </div>

            <div className="controls" style={{ paddingTop: 0 }}>
              <button
                className="btn btn--primary btn--block"
                type="button"
                onClick={() => navigate('/zero-waste/partners')}
              >
                View Partner
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  arrow_forward
                </span>
              </button>
            </div>

            {/* A completed recovery is evidence of what happened to real food.
                The page offers no edit, no delete and no re-run for the same
                reason the Activity Log does not. */}
            <p className="levels__note t-body-sm">
              Recovery records are read-only. Corrections are made by the
              backend that wrote them, never from the console.
            </p>
          </aside>
        )}
      </section>
    </ConsoleLayout>
  );
}
