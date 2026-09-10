import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import { SAMPLE_LOCATIONS } from './data/sampleLocations';
import {
  ZONE_STATUS_LABEL,
  type LocationDirectory,
  type ZoneStatus,
} from './data/locationTypes';
import { SAMPLE_NETWORK_STATUS } from '../rescues/data/sampleRescues';
import type { NetworkStatus } from '../rescues/data/rescueTypes';

const STATUS_COLOR: Record<ZoneStatus, string> = {
  live: 'var(--success)',
  strained: 'var(--warning-deep)',
  expanded: 'var(--primary)',
  paused: 'var(--on-surface-variant)',
};

type StatusFilter = 'all' | ZoneStatus;

/**
 * "FoodLoop Rescue Operations Console - Locations Management".
 *
 * The geography the network operates over: the zones, the dispatch radius in
 * force in each, the partner and rescuer density behind that radius, and the
 * pickup points registered inside it.
 *
 * This is the standing configuration behind Dynamic Rescue Coverage. That page
 * answers "should we widen the band for *this* rescue, right now"; this one
 * answers "what is this zone's normal, and is it holding". A zone that keeps
 * expanding shows up here as a supply problem rather than a series of
 * individual escalations.
 *
 * **No Stitch design.** Built from the console's own tokens and primitives,
 * reusing the Management directory shape established by Restaurants.
 *
 * **Nothing here changes the network.** Editing a radius, pausing a zone or
 * resuming one all steer real dispatch, so those controls are disabled until
 * the Phase 14 console API exists.
 */
export default function LocationsPage({
  data = SAMPLE_LOCATIONS,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: LocationDirectory;
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();

  const [tab, setTab] = useState<StatusFilter>('all');
  const [search, setSearch] = useState('');
  const [sector, setSector] = useState(data.sectors[0] ?? 'All Sectors');
  const [selectedId, setSelectedId] = useState<string | null>(
    data.rows[0]?.id ?? null,
  );

  const rows = useMemo(() => {
    const query = search.trim().toLowerCase();
    return data.rows.filter((row) => {
      const matchesTab = tab === 'all' || row.status === tab;
      const matchesSector = sector === data.sectors[0] || row.sector === sector;
      const matchesQuery =
        query.length === 0 ||
        row.name.toLowerCase().includes(query) ||
        row.id.toLowerCase().includes(query) ||
        row.sector.toLowerCase().includes(query);
      return matchesTab && matchesSector && matchesQuery;
    });
  }, [data.rows, data.sectors, tab, sector, search]);

  const selectedRow = data.rows.find((row) => row.id === selectedId) ?? null;
  const detail = selectedId ? data.details[selectedId] : undefined;

  const totalPartners = data.rows.reduce((sum, row) => sum + row.partners, 0);
  const totalRescuers = data.rows.reduce((sum, row) => sum + row.rescuers, 0);

  const tabs: { id: StatusFilter; label: string; count: number }[] = [
    { id: 'all', label: 'All', count: data.totals.all },
    { id: 'live', label: 'Live', count: data.totals.live },
    { id: 'strained', label: 'Strained', count: data.totals.strained },
    { id: 'expanded', label: 'Expanded', count: data.totals.expanded },
    { id: 'paused', label: 'Paused', count: data.totals.paused },
  ];

  return (
    <ConsoleLayout
      title="Locations"
      subtitle={`${data.totals.all} zones`}
      statusStrip={
        <ConsoleStatusStrip
          activeRescues={status.activeRescues}
          needIntervention={status.needIntervention}
          pickupsApproaching={status.pickupsApproaching}
          expandedCoverage={data.totals.expanded}
          version={status.consoleVersion}
        />
      }
    >
      <nav className="crumbs t-body-sm" aria-label="Breadcrumb">
        <span className="muted">Management</span>
        <span aria-hidden="true">&rsaquo;</span>
        <span className="muted">Locations</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">Locations Management</h1>
          <p className="t-body-md">
            The zones the network dispatches over: coverage radius in force,
            the partner and rescuer density behind it, and the pickup points
            registered inside each one.
          </p>
        </div>
        <div className="intro__actions">
          <span className="pill t-label-sm">
            <span
              className="dot dot--pulse"
              style={{ background: 'var(--success)' }}
            />
            {status.regionCoverage} network coverage
          </span>
          <span className="t-label-sm muted">Updated just now</span>
          {/* Opening a zone starts dispatching to real people in it. */}
          <button
            className="btn btn--primary"
            type="button"
            disabled
            title="Adding a zone needs the Phase 14 console API"
          >
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              add_location_alt
            </span>
            Add zone
          </button>
        </div>
      </section>

      <section className="kpis" aria-label="Network geography totals">
        <DirectoryKpi
          label="Active Zones"
          icon="distance"
          value={`${data.totals.all - data.totals.paused}`}
          caption={`${data.totals.paused} paused`}
        />
        <DirectoryKpi
          label="Expanded Coverage"
          icon="podcasts"
          value={`${data.totals.expanded}`}
          caption="Radius widened past standard"
          color="var(--primary)"
        />
        <DirectoryKpi
          label="Strained"
          icon="warning"
          value={`${data.totals.strained}`}
          caption="Demand outrunning rescuers"
          color="var(--warning-deep)"
        />
        <DirectoryKpi
          label="Avg. Dispatch"
          icon="timer"
          value={status.avgDispatch}
          caption={`${totalPartners} partners - ${totalRescuers} rescuers`}
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
            placeholder="Search zones, IDs, or sectors"
            aria-label="Search zones"
            style={{ paddingRight: 12 }}
          />
        </div>

        <div className="segmented" role="group" aria-label="Zone status">
          {tabs.map((entry) => (
            <button
              key={entry.id}
              type="button"
              aria-pressed={tab === entry.id}
              className={`segmented__btn t-label-md${
                tab === entry.id ? ' segmented__btn--on' : ''
              }`}
              onClick={() => setTab(entry.id)}
            >
              {entry.label} {entry.count}
            </button>
          ))}
        </div>

        <label className="visually-hidden" htmlFor="zone-sector">
          Filter by sector
        </label>
        <select
          id="zone-sector"
          className="select"
          style={{ height: 36, marginLeft: 'auto' }}
          value={sector}
          onChange={(event) => setSector(event.target.value)}
        >
          {data.sectors.map((option) => (
            <option key={option} value={option}>
              {option}
            </option>
          ))}
        </select>
      </section>

      <section className={`queuesplit${detail ? '' : ' queuesplit--wide'}`}>
        <div className="card">
          <div className="tablewrap">
            <table className="dtable">
              <thead>
                <tr>
                  <th scope="col">Zone</th>
                  <th scope="col">Status</th>
                  <th scope="col">Partners</th>
                  <th scope="col">Rescuers</th>
                  <th scope="col">Active</th>
                  <th scope="col">Radius</th>
                  <th scope="col">Coverage</th>
                  <th scope="col">Avg. Dispatch</th>
                </tr>
              </thead>
              <tbody>
                {rows.length === 0 && (
                  <tr>
                    <td colSpan={8} className="t-body-sm muted dtable__empty">
                      No zones match this filter.
                    </td>
                  </tr>
                )}

                {rows.map((row) => {
                  const widened = row.currentRadius !== row.standardRadius;
                  return (
                    <tr
                      key={row.id}
                      className={
                        row.id === selectedId ? 'dtable__row--on' : undefined
                      }
                      onClick={() => setSelectedId(row.id)}
                    >
                      <td>
                        <span style={{ minWidth: 0 }}>
                          <span
                            className="t-body-md"
                            style={{ fontWeight: 600 }}
                          >
                            {row.name}
                          </span>
                          <span className="dtable__sub t-body-sm muted">
                            {row.id} - {row.sector}
                          </span>
                        </span>
                      </td>
                      <td>
                        <span
                          className="dtable__state t-label-sm"
                          style={{ color: STATUS_COLOR[row.status] }}
                        >
                          <span
                            className={`dot${
                              row.status === 'live' ? ' dot--pulse' : ''
                            }`}
                            style={{ background: STATUS_COLOR[row.status] }}
                          />
                          {ZONE_STATUS_LABEL[row.status]}
                        </span>
                      </td>
                      <td className="t-body-sm">{row.partners}</td>
                      <td className="t-body-sm">{row.rescuers}</td>
                      <td className="t-body-sm">{row.activeRescues}</td>
                      <td className="t-body-sm">
                        <span style={{ minWidth: 0 }}>
                          <span
                            style={{
                              fontWeight: widened ? 600 : 400,
                              color: widened ? 'var(--primary)' : undefined,
                            }}
                          >
                            {row.currentRadius}
                          </span>
                          {widened && (
                            <span className="dtable__sub t-label-sm muted">
                              standard {row.standardRadius}
                            </span>
                          )}
                        </span>
                      </td>
                      <td className="t-body-sm">{row.coverage}</td>
                      <td className="t-body-sm muted">{row.avgDispatch}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <div className="queue__foot t-body-sm">
            <span>
              Showing {rows.length} of {data.totals.all} zones
            </span>
            <span className="t-label-sm muted">
              Radius shown is the band in force right now
            </span>
          </div>
        </div>

        {detail && selectedRow && (
          <aside className="card" aria-label={`${selectedRow.name} detail`}>
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <h2 className="t-headline-sm truncate" style={{ margin: 0 }}>
                    {selectedRow.name}
                  </h2>
                  <span
                    className="chip t-label-sm"
                    style={{
                      background:
                        selectedRow.status === 'live'
                          ? 'var(--primary-fixed)'
                          : selectedRow.status === 'strained'
                            ? 'var(--warning-bg)'
                            : 'var(--surface-container)',
                      color: STATUS_COLOR[selectedRow.status],
                    }}
                  >
                    {ZONE_STATUS_LABEL[selectedRow.status]}
                  </span>
                </div>
                <span className="t-body-sm muted">
                  {selectedRow.id} &middot; {selectedRow.sector} &middot;{' '}
                  {detail.area}
                </span>
              </div>
              <button
                className="iconbtn"
                type="button"
                onClick={() => setSelectedId(null)}
                aria-label="Close zone detail"
              >
                <span className="icon" style={{ fontSize: 18 }}>
                  close
                </span>
              </button>
            </div>

            <div
              className={`alertcard ${
                selectedRow.status === 'strained'
                  ? 'alertcard--error'
                  : selectedRow.status === 'expanded'
                    ? 'alertcard--info'
                    : selectedRow.status === 'paused'
                      ? 'alertcard--neutral'
                      : 'alertcard--good'
              }`}
            >
              <span className="t-body-sm">{detail.summary}</span>
            </div>

            <div className="statgrid">
              <DetailStat
                label="Radius In Force"
                value={selectedRow.currentRadius}
              />
              <DetailStat
                label="Standard"
                value={selectedRow.standardRadius}
              />
              <DetailStat label="Coverage" value={selectedRow.coverage} />
              <DetailStat
                label="Avg. Dispatch"
                value={selectedRow.avgDispatch}
              />
            </div>

            <div className="section-head">
              <h3 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                Zone Profile
              </h3>
            </div>

            <dl className="factlist">
              <div className="factlist__row">
                <dt className="t-body-sm muted">Population Served</dt>
                <dd className="t-body-md">{detail.population}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Partners / Rescuers</dt>
                <dd className="t-body-md">
                  {selectedRow.partners} / {selectedRow.rescuers}
                </dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Peak Window</dt>
                <dd className="t-body-md">{detail.peakWindow}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Unmatched Rate</dt>
                <dd className="t-body-md">{detail.unmatchedRate}</dd>
              </div>
            </dl>

            <div className="section-head">
              <h3 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                Pickup Points
              </h3>
              <span className="t-label-sm muted">
                {detail.pickupPoints.filter((point) => point.active).length} of{' '}
                {detail.pickupPoints.length} active
              </span>
            </div>

            <ul className="factlist">
              {detail.pickupPoints.map((point) => (
                <li className="factlist__row" key={point.name}>
                  <span style={{ minWidth: 0 }}>
                    <span className="t-body-md" style={{ fontWeight: 600 }}>
                      {point.name}
                    </span>
                    <span className="dtable__sub t-body-sm muted">
                      {point.kind} &middot; {point.hours}
                    </span>
                  </span>
                  <span
                    className="dtable__state t-label-sm"
                    style={{
                      color: point.active
                        ? 'var(--success)'
                        : 'var(--on-surface-variant)',
                    }}
                  >
                    <span
                      className="dot"
                      style={{
                        background: point.active
                          ? 'var(--success)'
                          : 'var(--outline-variant)',
                      }}
                    />
                    {point.active ? 'Active' : 'Inactive'}
                  </span>
                </li>
              ))}
            </ul>

            <div className="section-head">
              <h3 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                Coverage History
              </h3>
            </div>

            <ol className="audit">
              {detail.events.map((entry) => (
                <li className="audit__row" key={`${entry.when}-${entry.title}`}>
                  <span className="audit__rail" aria-hidden="true">
                    <span
                      className="audit__dot"
                      style={{ background: 'var(--outline-variant)' }}
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
                  </div>
                </li>
              ))}
            </ol>

            <div className="controls" style={{ paddingTop: 0 }}>
              <button
                className="btn btn--primary btn--block"
                type="button"
                onClick={() => navigate('/live-rescues')}
                disabled={selectedRow.activeRescues === 0}
                title={
                  selectedRow.activeRescues === 0
                    ? 'No rescues are active in this zone'
                    : undefined
                }
              >
                <span
                  className="icon"
                  style={{ fontSize: 15 }}
                  aria-hidden="true"
                >
                  cyclone
                </span>
                View active rescues ({selectedRow.activeRescues})
              </button>

              {/* Each of these steers real dispatch in a real place. */}
              <button
                className="btn btn--quiet btn--block"
                type="button"
                disabled
                title="Editing the coverage radius needs the Phase 14 console API"
              >
                Edit coverage radius
              </button>
              <button
                className="btn btn--quiet btn--block"
                type="button"
                disabled
                title="Managing pickup points needs the Phase 14 console API"
              >
                Manage pickup points
              </button>
              <button
                className={`btn btn--block ${
                  selectedRow.status === 'paused' ? 'btn--quiet' : 'btn--danger'
                }`}
                type="button"
                disabled
                title="Pausing or resuming a zone needs the Phase 14 console API"
              >
                {selectedRow.status === 'paused'
                  ? 'Resume dispatch in this zone'
                  : 'Pause dispatch in this zone'}
              </button>
            </div>
          </aside>
        )}
      </section>
    </ConsoleLayout>
  );
}

function DirectoryKpi({
  label,
  icon,
  value,
  caption,
  color = 'var(--primary)',
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

function DetailStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="statgrid__cell">
      <span className="t-label-sm upper muted">{label}</span>
      <span className="t-body-md" style={{ fontWeight: 600 }}>
        {value}
      </span>
    </div>
  );
}
