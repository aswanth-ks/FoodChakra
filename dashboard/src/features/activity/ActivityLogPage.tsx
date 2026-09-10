import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import { SAMPLE_ACTIVITY } from './data/sampleActivity';
import {
  ACTOR_LABEL,
  CATEGORY_LABEL,
  OUTCOME_LABEL,
  type ActivityLog,
  type ActorKind,
  type EventCategory,
  type EventOutcome,
} from './data/activityTypes';
import { SAMPLE_NETWORK_STATUS } from '../rescues/data/sampleRescues';
import type { NetworkStatus } from '../rescues/data/rescueTypes';

const OUTCOME_COLOR: Record<EventOutcome, string> = {
  ok: 'var(--success)',
  warning: 'var(--warning-deep)',
  failed: 'var(--error)',
};

const ACTOR_ICON: Record<ActorKind, string> = {
  operator: 'person',
  system: 'smart_toy',
  partner: 'storefront',
  rescuer: 'sports_motorsports',
};

type ActorFilter = 'all' | ActorKind;

/**
 * "FoodLoop Rescue Operations Console - Activity Log".
 *
 * The audit trail: what happened on the network, who or what caused it, and
 * how it ended. Every other console page shows the present; this one is the
 * record, and it is the only place an operator decision can be traced back to
 * the person who made it.
 *
 * **No Stitch design.** Built from the console's own tokens and primitives.
 * It is a log rather than a directory, so the layout is a filter bar over a
 * dense table with an inspection panel - the Rescue Queue shape - rather than
 * the Restaurants dossier shape.
 *
 * **This is a read-only view, and it must stay that way.** An audit log an
 * operator can edit is not an audit log. The only disabled control here is
 * export, which needs the Phase 14 console API to produce a signed file; there
 * is deliberately no delete, no edit, and no retention control on this page.
 *
 * **The entries are fixtures, not a real trail.** Nothing in this console has
 * written an audit record yet, because nothing has performed a real action.
 * The page says so in-page rather than implying these events were logged.
 */
export default function ActivityLogPage({
  data = SAMPLE_ACTIVITY,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: ActivityLog;
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();

  const [actor, setActor] = useState<ActorFilter>('all');
  const [category, setCategory] = useState<'all' | EventCategory>('all');
  const [search, setSearch] = useState('');
  const [range, setRange] = useState(data.ranges[0] ?? 'Last 24 hours');
  const [failedOnly, setFailedOnly] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(
    data.entries[0]?.id ?? null,
  );

  const entries = useMemo(() => {
    const query = search.trim().toLowerCase();
    return data.entries.filter((entry) => {
      const matchesActor = actor === 'all' || entry.actorKind === actor;
      const matchesCategory =
        category === 'all' || entry.category === category;
      const matchesOutcome = !failedOnly || entry.outcome === 'failed';
      const matchesQuery =
        query.length === 0 ||
        entry.actor.toLowerCase().includes(query) ||
        entry.action.toLowerCase().includes(query) ||
        entry.target.toLowerCase().includes(query) ||
        entry.id.toLowerCase().includes(query);
      return matchesActor && matchesCategory && matchesOutcome && matchesQuery;
    });
  }, [data.entries, actor, category, failedOnly, search]);

  const selected =
    data.entries.find((entry) => entry.id === selectedId) ?? null;

  const actorTabs: { id: ActorFilter; label: string }[] = [
    { id: 'all', label: 'All' },
    { id: 'operator', label: 'Operator' },
    { id: 'system', label: 'System' },
    { id: 'partner', label: 'Partner' },
    { id: 'rescuer', label: 'Rescuer' },
  ];

  const categories: ('all' | EventCategory)[] = [
    'all',
    'rescue',
    'escalation',
    'coverage',
    'account',
    'auth',
  ];

  return (
    <ConsoleLayout
      title="Activity Log"
      subtitle={range}
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
        <span className="muted">Management</span>
        <span aria-hidden="true">&rsaquo;</span>
        <span className="muted">Activity</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">Activity Log</h1>
          <p className="t-body-md">
            The audit trail for the rescue network: every operator decision,
            automated escalation and app event, with who caused it and how it
            ended.
          </p>
        </div>
        <div className="intro__actions">
          <span className="pill t-label-sm">
            <span
              className="dot dot--pulse"
              style={{ background: 'var(--success)' }}
            />
            {data.totals.all} events
          </span>
          <span className="t-label-sm muted">Updated just now</span>
          {/* An exported audit file has to be produced and signed server-side;
              a CSV assembled in the browser would not be evidence of anything. */}
          <button
            className="btn btn--primary"
            type="button"
            disabled
            title="Export needs the Phase 14 console API"
          >
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              download
            </span>
            Export log
          </button>
        </div>
      </section>

      {/* `.alertcard` is inset for use inside a card; this one is a top-level
          section, so it sits flush like the other page sections. */}
      <div className="alertcard alertcard--info" style={{ margin: 0 }}>
        <span className="t-body-sm">
          <strong>These entries are fixtures.</strong> No console action has
          been recorded yet, because no console action reaches a backend. Phase
          14 replaces this with the real audit trail, which is the only version
          that can be relied on.
        </span>
      </div>

      <section className="kpis" aria-label="Activity totals">
        <LogKpi
          label="Events"
          icon="history"
          value={`${data.totals.all}`}
          caption={range}
        />
        <LogKpi
          label="Operator Actions"
          icon="person"
          value={`${data.totals.operator}`}
          caption="Decisions made by a named person"
          color="var(--primary)"
        />
        <LogKpi
          label="System Events"
          icon="smart_toy"
          value={`${data.totals.system}`}
          caption="Automation acting on its own rules"
        />
        <LogKpi
          label="Failed"
          icon="error"
          value={`${data.totals.failed}`}
          caption="Did not complete"
          color="var(--error)"
        />
      </section>

      <section className="card queuebar">
        <div className="topbar__search" style={{ maxWidth: 300 }}>
          <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
            search
          </span>
          <input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search actors, actions, or event IDs"
            aria-label="Search the activity log"
            style={{ paddingRight: 12 }}
          />
        </div>

        <div className="segmented" role="group" aria-label="Actor">
          {actorTabs.map((entry) => (
            <button
              key={entry.id}
              type="button"
              aria-pressed={actor === entry.id}
              className={`segmented__btn t-label-md${
                actor === entry.id ? ' segmented__btn--on' : ''
              }`}
              onClick={() => setActor(entry.id)}
            >
              {entry.label}
            </button>
          ))}
        </div>

        <label className="visually-hidden" htmlFor="log-range">
          Time range
        </label>
        <select
          id="log-range"
          className="select"
          style={{ height: 36, marginLeft: 'auto' }}
          value={range}
          onChange={(event) => setRange(event.target.value)}
        >
          {data.ranges.map((option) => (
            <option key={option} value={option}>
              {option}
            </option>
          ))}
        </select>
      </section>

      <section className="pillrow" aria-label="Event category">
        {categories.map((entry) => (
          <button
            key={entry}
            type="button"
            aria-pressed={category === entry}
            className={`filterpill t-label-md${
              category === entry ? ' filterpill--on' : ''
            }`}
            onClick={() => setCategory(entry)}
          >
            {entry === 'all' ? 'All categories' : CATEGORY_LABEL[entry]}
          </button>
        ))}
        <button
          type="button"
          aria-pressed={failedOnly}
          className={`filterpill t-label-md${failedOnly ? ' filterpill--on' : ''}`}
          onClick={() => setFailedOnly((on) => !on)}
          style={{ marginLeft: 'auto' }}
        >
          <span className="icon" style={{ fontSize: 14 }} aria-hidden="true">
            error
          </span>
          Failures only
        </button>
      </section>

      <section className={`queuesplit${selected ? '' : ' queuesplit--wide'}`}>
        <div className="card">
          <div className="tablewrap">
            <table className="dtable">
              <thead>
                <tr>
                  <th scope="col">Time</th>
                  <th scope="col">Actor</th>
                  <th scope="col">Action</th>
                  <th scope="col">Target</th>
                  <th scope="col">Category</th>
                  <th scope="col">Outcome</th>
                </tr>
              </thead>
              <tbody>
                {entries.length === 0 && (
                  <tr>
                    <td colSpan={6} className="t-body-sm muted dtable__empty">
                      No events match this filter.
                    </td>
                  </tr>
                )}

                {entries.map((entry) => (
                  <tr
                    key={entry.id}
                    className={
                      entry.id === selectedId ? 'dtable__row--on' : undefined
                    }
                    onClick={() => setSelectedId(entry.id)}
                  >
                    <td className="t-body-sm">
                      <span style={{ minWidth: 0 }}>
                        <span style={{ fontWeight: 600 }}>{entry.clock}</span>
                        <span className="dtable__sub t-label-sm muted">
                          {entry.relative}
                        </span>
                      </span>
                    </td>
                    <td className="t-body-sm">
                      <span
                        className="dtable__state"
                        style={{ alignItems: 'flex-start' }}
                      >
                        <span
                          className="icon muted"
                          style={{ fontSize: 16 }}
                          aria-hidden="true"
                        >
                          {ACTOR_ICON[entry.actorKind]}
                        </span>
                        <span style={{ minWidth: 0 }}>
                          <span style={{ fontWeight: 600 }}>{entry.actor}</span>
                          <span className="dtable__sub t-label-sm muted">
                            {ACTOR_LABEL[entry.actorKind]}
                          </span>
                        </span>
                      </span>
                    </td>
                    <td className="t-body-sm">{entry.action}</td>
                    <td className="t-body-sm muted">{entry.target}</td>
                    <td className="t-body-sm">
                      <span className="chip t-label-sm">
                        {CATEGORY_LABEL[entry.category]}
                      </span>
                    </td>
                    <td>
                      <span
                        className="dtable__state t-label-sm"
                        style={{ color: OUTCOME_COLOR[entry.outcome] }}
                      >
                        <span
                          className="dot"
                          style={{ background: OUTCOME_COLOR[entry.outcome] }}
                        />
                        {OUTCOME_LABEL[entry.outcome]}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="queue__foot t-body-sm">
            <span>
              Showing {entries.length} of {data.entries.length} loaded events
            </span>
            <span className="pager">
              {/* Paging the full trail needs the Phase 14 console API. */}
              <button className="btn btn--quiet" type="button" disabled>
                Load older events
              </button>
            </span>
          </div>
        </div>

        {selected && (
          <aside className="card" aria-label={`Event ${selected.id}`}>
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <h2 className="t-headline-sm truncate" style={{ margin: 0 }}>
                  {selected.action}
                </h2>
                <span className="t-body-sm muted">
                  {selected.id} &middot; {selected.clock}
                </span>
              </div>
              <button
                className="iconbtn"
                type="button"
                onClick={() => setSelectedId(null)}
                aria-label="Close event detail"
              >
                <span className="icon" style={{ fontSize: 18 }}>
                  close
                </span>
              </button>
            </div>

            <div
              className={`alertcard ${
                selected.outcome === 'failed'
                  ? 'alertcard--error'
                  : selected.outcome === 'warning'
                    ? 'alertcard--info'
                    : 'alertcard--good'
              }`}
            >
              <span className="t-body-sm">{selected.detail}</span>
            </div>

            <div className="statgrid">
              <EventStat
                label="Outcome"
                value={OUTCOME_LABEL[selected.outcome]}
              />
              <EventStat
                label="Category"
                value={CATEGORY_LABEL[selected.category]}
              />
              <EventStat
                label="Actor Type"
                value={ACTOR_LABEL[selected.actorKind]}
              />
              <EventStat label="When" value={selected.relative} />
            </div>

            <div className="section-head">
              <h3 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                Record
              </h3>
            </div>

            <dl className="factlist">
              <div className="factlist__row">
                <dt className="t-body-sm muted">Event ID</dt>
                <dd className="t-body-md">{selected.id}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Actor</dt>
                <dd className="t-body-md">{selected.actor}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Target</dt>
                <dd className="t-body-md">{selected.target}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Timestamp</dt>
                <dd className="t-body-md">{selected.at}</dd>
              </div>
              {selected.source && (
                <div className="factlist__row">
                  <dt className="t-body-sm muted">Source</dt>
                  <dd className="t-body-md">{selected.source}</dd>
                </div>
              )}
            </dl>

            <div className="controls" style={{ paddingTop: 0 }}>
              {selected.rescueId ? (
                <button
                  className="btn btn--primary btn--block"
                  type="button"
                  onClick={() => navigate(`/live-rescues/${selected.rescueId}`)}
                >
                  <span
                    className="icon"
                    style={{ fontSize: 15 }}
                    aria-hidden="true"
                  >
                    cyclone
                  </span>
                  Open rescue #{selected.rescueId}
                </button>
              ) : (
                <div className="t-body-sm muted">
                  This event does not reference a rescue.
                </div>
              )}

              {/* An audit log is read-only by definition: the page offers no
                  edit, no delete and no retention control, only a signed
                  export the server has to produce. */}
              <button
                className="btn btn--quiet btn--block"
                type="button"
                disabled
                title="Export needs the Phase 14 console API"
              >
                Export this record
              </button>
            </div>
          </aside>
        )}
      </section>
    </ConsoleLayout>
  );
}

function LogKpi({
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
        <span
          className="icon muted"
          style={{ fontSize: 18 }}
          aria-hidden="true"
        >
          {icon}
        </span>
      </div>
      <div className="kpi__value">
        <span
          className="t-metric"
          style={{ fontSize: 32, lineHeight: '40px', color, fontWeight: 700 }}
        >
          {value}
        </span>
      </div>
      <div className="kpi__foot t-body-sm truncate">{caption}</div>
    </article>
  );
}

function EventStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="statgrid__cell">
      <span className="t-label-sm upper muted">{label}</span>
      <span className="t-body-md" style={{ fontWeight: 600 }}>
        {value}
      </span>
    </div>
  );
}
