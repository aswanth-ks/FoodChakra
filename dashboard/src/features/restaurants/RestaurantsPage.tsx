import { useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import { SAMPLE_PARTNERS } from './data/samplePartners';
import {
  PARTNER_STATUS_LABEL,
  type PartnerDirectory,
  type PartnerStatus,
} from './data/partnerTypes';
import { SAMPLE_NETWORK_STATUS } from '../rescues/data/sampleRescues';
import type { NetworkStatus } from '../rescues/data/rescueTypes';

const STATUS_COLOR: Record<PartnerStatus, string> = {
  active: 'var(--success)',
  attention: 'var(--warning-deep)',
  inactive: 'var(--on-surface-variant)',
};

type StatusFilter = 'all' | PartnerStatus;

/**
 * "FoodLoop Rescue Operations Console — Restaurants".
 *
 * Faithful translation of the Stitch design
 * (screen `0db51c916c3441faa27126cf53fa3b05`).
 *
 * The partner directory: who is on the network, how they are performing, and
 * a dossier for whoever is selected. Onboarding a *new* partner is its own
 * destination — see `/restaurants/onboard`.
 *
 * **Design divergence:** the mock redraws the sidebar and status bar; both
 * come from the shared console layout, as on every other console page.
 */
export default function RestaurantsPage({
  data = SAMPLE_PARTNERS,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: PartnerDirectory;
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();

  const [tab, setTab] = useState<StatusFilter>('all');
  const [search, setSearch] = useState('');
  const [location, setLocation] = useState(data.locations[0] ?? 'All Locations');
  const [selectedId, setSelectedId] = useState<string | null>(
    data.rows[0]?.id ?? null,
  );

  const rows = useMemo(() => {
    const query = search.trim().toLowerCase();
    return data.rows.filter((row) => {
      const matchesTab = tab === 'all' || row.status === tab;
      const matchesLocation =
        location === data.locations[0] || row.location === location;
      const matchesQuery =
        query.length === 0 ||
        row.name.toLowerCase().includes(query) ||
        row.id.toLowerCase().includes(query) ||
        row.location.toLowerCase().includes(query);
      return matchesTab && matchesLocation && matchesQuery;
    });
  }, [data.rows, data.locations, tab, location, search]);

  const selectedRow = data.rows.find((row) => row.id === selectedId) ?? null;
  const dossier = selectedId ? data.dossiers[selectedId] : undefined;

  const tabs: { id: StatusFilter; label: string; count: number }[] = [
    { id: 'all', label: 'All', count: data.totals.all },
    { id: 'active', label: 'Active', count: data.totals.active },
    { id: 'attention', label: 'Attention', count: data.totals.attention },
    { id: 'inactive', label: 'Inactive', count: data.totals.inactive },
  ];

  return (
    <ConsoleLayout
      title="Restaurant Partners"
      subtitle={`${data.totals.all} partners`}
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
        <span aria-hidden="true">›</span>
        <span className="muted">Restaurants</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">Restaurant Partners</h1>
          <p className="t-body-md">
            Monitor verified restaurant partners and their rescue activity
            across the FoodLoop network.
          </p>
        </div>
        <div className="intro__actions">
          <span className="pill t-label-sm">
            <span className="dot dot--pulse" style={{ background: 'var(--success)' }} />
            {data.totals.all} partners
          </span>
          <span className="t-label-sm muted">Updated just now</span>
          <Link className="btn btn--primary" to="/restaurants/onboard">
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              add
            </span>
            Onboard Restaurant
          </Link>
        </div>
      </section>

      <section className="kpis" aria-label="Partner totals">
        <DirectoryKpi
          label="Total Partners"
          icon="storefront"
          value={data.totals.all}
          caption="Registered in network"
        />
        <DirectoryKpi
          label="Active"
          icon="check_circle"
          value={data.totals.active}
          caption="Publishing surplus"
          color="var(--success)"
        />
        <DirectoryKpi
          label="Attention"
          icon="warning"
          value={data.totals.attention}
          caption="Requires operator review"
          color="var(--warning-deep)"
        />
        <DirectoryKpi
          label="Inactive"
          icon="bedtime"
          value={data.totals.inactive}
          caption="Dormant >14 days"
          color="var(--on-surface-variant)"
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
            placeholder="Search partners, IDs, or areas"
            aria-label="Search restaurant partners"
            style={{ paddingRight: 12 }}
          />
        </div>

        <div className="segmented" role="group" aria-label="Partner status">
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

        <label className="visually-hidden" htmlFor="partner-location">
          Filter by location
        </label>
        <select
          id="partner-location"
          className="select"
          style={{ height: 36, marginLeft: 'auto' }}
          value={location}
          onChange={(event) => setLocation(event.target.value)}
        >
          {data.locations.map((option) => (
            <option key={option} value={option}>
              {option}
            </option>
          ))}
        </select>
      </section>

      <section className={`queuesplit${dossier ? '' : ' queuesplit--wide'}`}>
        <div className="card">
          <div className="tablewrap">
            <table className="dtable">
              <thead>
                <tr>
                  <th scope="col">Restaurant</th>
                  <th scope="col">Location</th>
                  <th scope="col">Status</th>
                  <th scope="col">Active Rescues</th>
                  <th scope="col">Completed</th>
                  <th scope="col">Last Activity</th>
                  <th scope="col">
                    <span className="visually-hidden">Action</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.length === 0 && (
                  <tr>
                    <td colSpan={7} className="t-body-sm muted dtable__empty">
                      No partners match this filter.
                    </td>
                  </tr>
                )}

                {rows.map((row) => (
                  <tr
                    key={row.id}
                    className={row.id === selectedId ? 'dtable__row--on' : undefined}
                    onClick={() => setSelectedId(row.id)}
                  >
                    <td>
                      <span className="partnercell">
                        <span className="avatar t-label-md" aria-hidden="true">
                          {row.initials}
                        </span>
                        <span style={{ minWidth: 0 }}>
                          <span className="t-body-md" style={{ fontWeight: 600 }}>
                            {row.name}
                          </span>
                          <span className="dtable__sub t-body-sm muted">
                            ID: #{row.id}
                          </span>
                        </span>
                      </span>
                    </td>
                    <td className="t-body-sm">{row.location}</td>
                    <td>
                      <span
                        className="dtable__state t-label-sm"
                        style={{ color: STATUS_COLOR[row.status] }}
                      >
                        <span
                          className="dot"
                          style={{ background: STATUS_COLOR[row.status] }}
                        />
                        {PARTNER_STATUS_LABEL[row.status]}
                      </span>
                    </td>
                    <td className="t-body-sm">{row.activeRescues} active</td>
                    <td className="t-body-sm">{row.completed} completed</td>
                    <td className="t-body-sm muted">{row.lastActivity}</td>
                    <td style={{ textAlign: 'right' }}>
                      <button
                        className="btn btn--quiet"
                        type="button"
                        onClick={(event) => {
                          event.stopPropagation();
                          setSelectedId(row.id);
                        }}
                      >
                        Open
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="queue__foot t-body-sm">
            <span>
              Showing {rows.length} of {data.totals.all} partners
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

        {dossier && selectedRow && (
          <aside className="card" aria-label={`${selectedRow.name} dossier`}>
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <h2 className="t-headline-sm truncate" style={{ margin: 0 }}>
                    {selectedRow.name}
                  </h2>
                  {dossier.verified && (
                    <span
                      className="chip t-label-sm"
                      style={{
                        background: 'var(--primary-fixed)',
                        color: 'var(--on-primary-fixed)',
                      }}
                    >
                      <span className="icon" style={{ fontSize: 13 }} aria-hidden="true">
                        verified
                      </span>
                      Verified
                    </span>
                  )}
                </div>
                <span className="t-body-sm muted">{dossier.branchLine}</span>
              </div>
              <button
                className="iconbtn"
                type="button"
                onClick={() => setSelectedId(null)}
                aria-label="Close dossier"
              >
                <span className="icon" style={{ fontSize: 18 }}>
                  close
                </span>
              </button>
            </div>

            <div className="statgrid">
              <DossierStat label="Current Rescues" value={`${selectedRow.activeRescues} active`} />
              <DossierStat label="Completed" value={`${selectedRow.completed}`} />
              <DossierStat label="Success Rate" value={dossier.successRate} />
              <DossierStat label="Last Activity" value={selectedRow.lastActivity} />
            </div>

            <div className="section-head">
              <h3 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                Partner Operations
              </h3>
              <span
                className="chip t-label-sm"
                style={{
                  background:
                    selectedRow.status === 'attention'
                      ? 'var(--warning-bg)'
                      : 'var(--primary-fixed)',
                  color:
                    selectedRow.status === 'attention'
                      ? 'var(--warning-deep)'
                      : 'var(--on-primary-fixed)',
                }}
              >
                {dossier.healthLabel}
              </span>
            </div>

            <dl className="factlist">
              <div className="factlist__row">
                <dt className="t-body-sm muted">Rescue Participation</dt>
                <dd className="t-body-md">{dossier.participation}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Pickup Readiness</dt>
                <dd className="t-body-md">{dossier.pickupReadiness}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Recent Incidents</dt>
                <dd className="t-body-md">{dossier.incidents}</dd>
              </div>
            </dl>

            <div className="section-head">
              <h3 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                Recent Rescue Activity
              </h3>
              <span className="t-label-sm muted dtable__state">
                <span className="dot dot--pulse" style={{ background: 'var(--success)' }} />
                Real-time sync
              </span>
            </div>

            <ol className="audit">
              {dossier.activity.map((entry) => (
                <li className="audit__row" key={entry.subject}>
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
                    <div className="t-body-sm">{entry.subject}</div>
                    <div className="t-body-sm muted">{entry.detail}</div>
                    {entry.rescueId && (
                      <button
                        className="linkbtn t-label-md"
                        type="button"
                        onClick={() => navigate(`/live-rescues/${entry.rescueId}`)}
                      >
                        Open Rescue Detail ↗
                      </button>
                    )}
                  </div>
                </li>
              ))}
            </ol>

            <div className="controls" style={{ paddingTop: 0 }}>
              {/* The partner profile and operational log are their own pages,
                  neither of which is built yet. */}
              <button
                className="btn btn--primary btn--block"
                type="button"
                disabled
                title="Partner profile — not built yet"
              >
                Open partner profile
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  arrow_forward
                </span>
              </button>
              <button
                className="btn btn--quiet btn--block"
                type="button"
                onClick={() => navigate('/live-rescues')}
              >
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  cyclone
                </span>
                View active rescues ({selectedRow.activeRescues})
              </button>
              <button
                className="btn btn--quiet btn--block"
                type="button"
                disabled
                title="Operational log — not built yet"
              >
                View operational log
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
  value: number;
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
          style={{ fontSize: 32, lineHeight: '40px', color, fontWeight: 700 }}
        >
          {value}
        </span>
      </div>
      <div className="kpi__foot t-body-sm truncate">{caption}</div>
    </article>
  );
}

function DossierStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="statgrid__cell">
      <span className="t-label-sm upper muted">{label}</span>
      <span className="t-body-md" style={{ fontWeight: 600 }}>
        {value}
      </span>
    </div>
  );
}
