import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import { SAMPLE_RESCUERS } from './data/sampleRescuers';
import {
  RESCUER_STATUS_LABEL,
  VERIFICATION_LABEL,
  type RescuerDirectory,
  type RescuerStatus,
  type VerificationState,
} from './data/rescuerTypes';
import { SAMPLE_NETWORK_STATUS } from '../rescues/data/sampleRescues';
import type { NetworkStatus } from '../rescues/data/rescueTypes';

const STATUS_COLOR: Record<RescuerStatus, string> = {
  on_rescue: 'var(--success)',
  available: 'var(--primary)',
  offline: 'var(--on-surface-variant)',
  suspended: 'var(--error)',
};

const VERIFICATION_COLOR: Record<VerificationState, string> = {
  verified: 'var(--success)',
  pending: 'var(--warning-deep)',
  expired: 'var(--error)',
};

type StatusFilter = 'all' | RescuerStatus;

/**
 * "FoodLoop Rescue Operations Console - Rescuers Management".
 *
 * The people side of the network: who is on shift, who is carrying a rescue
 * right now, and how each rescuer is performing. Restaurants answers the same
 * question for supply; this answers it for capacity.
 *
 * **No Stitch design.** Like Console Sign In, this screen is built from the
 * console's own tokens and primitives rather than translated from a mock, so
 * it deliberately reuses the Restaurants directory shape (KPIs, filter bar,
 * table, dossier) instead of inventing a second layout language for the same
 * job.
 *
 * **Nothing here acts on a rescuer.** Suspending, reinstating, approving
 * verification and reassigning a live rescue all change what a real person is
 * doing, so every one of those controls is disabled until the Phase 14 console
 * API exists to carry the decision and record who made it.
 *
 * **Role-model note (blocker B7):** whether a rescuer is a distinct account
 * type or simply a Consumer currently rescuing is undecided. This page treats
 * "rescuer" as a capability on an account, which holds either way; if B7 lands
 * on a separate role, only the fixture source changes.
 */
export default function RescuersPage({
  data = SAMPLE_RESCUERS,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: RescuerDirectory;
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();

  const [tab, setTab] = useState<StatusFilter>('all');
  const [search, setSearch] = useState('');
  const [zone, setZone] = useState(data.zones[0] ?? 'All Zones');
  const [selectedId, setSelectedId] = useState<string | null>(
    data.rows[0]?.id ?? null,
  );

  const rows = useMemo(() => {
    const query = search.trim().toLowerCase();
    return data.rows.filter((row) => {
      const matchesTab = tab === 'all' || row.status === tab;
      const matchesZone = zone === data.zones[0] || row.zone === zone;
      const matchesQuery =
        query.length === 0 ||
        row.name.toLowerCase().includes(query) ||
        row.id.toLowerCase().includes(query) ||
        row.zone.toLowerCase().includes(query);
      return matchesTab && matchesZone && matchesQuery;
    });
  }, [data.rows, data.zones, tab, zone, search]);

  const selectedRow = data.rows.find((row) => row.id === selectedId) ?? null;
  const dossier = selectedId ? data.dossiers[selectedId] : undefined;

  const onShift = data.totals.onRescue + data.totals.available;

  const tabs: { id: StatusFilter; label: string; count: number }[] = [
    { id: 'all', label: 'All', count: data.totals.all },
    { id: 'on_rescue', label: 'On Rescue', count: data.totals.onRescue },
    { id: 'available', label: 'Available', count: data.totals.available },
    { id: 'offline', label: 'Offline', count: data.totals.offline },
    { id: 'suspended', label: 'Suspended', count: data.totals.suspended },
  ];

  return (
    <ConsoleLayout
      title="Rescuers"
      subtitle={`${onShift} on shift`}
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
        <span className="muted">Rescuers</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">Rescuers Management</h1>
          <p className="t-body-md">
            Rescue capacity across the network: who is on shift, who is carrying
            a rescue, and how reliably each rescuer completes one.
          </p>
        </div>
        <div className="intro__actions">
          <span className="pill t-label-sm">
            <span
              className="dot dot--pulse"
              style={{ background: 'var(--success)' }}
            />
            {onShift} on shift
          </span>
          <span className="t-label-sm muted">Updated just now</span>
          {/* Inviting a rescuer sends a real email and issues a real account;
              only the backend can do that. */}
          <button
            className="btn btn--primary"
            type="button"
            disabled
            title="Inviting a rescuer needs the Phase 14 console API"
          >
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              person_add
            </span>
            Invite rescuer
          </button>
        </div>
      </section>

      <section className="kpis" aria-label="Rescuer totals">
        <DirectoryKpi
          label="Registered"
          icon="groups"
          value={data.totals.all}
          caption="Accounts with rescue capability"
        />
        <DirectoryKpi
          label="On Rescue"
          icon="local_shipping"
          value={data.totals.onRescue}
          caption="Currently carrying a rescue"
          color="var(--success)"
        />
        <DirectoryKpi
          label="Available"
          icon="how_to_reg"
          value={data.totals.available}
          caption="On shift, awaiting a match"
          color="var(--primary)"
        />
        <DirectoryKpi
          label="Suspended"
          icon="block"
          value={data.totals.suspended}
          caption="Blocked by operator decision"
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
            placeholder="Search rescuers, IDs, or zones"
            aria-label="Search rescuers"
            style={{ paddingRight: 12 }}
          />
        </div>

        <div className="segmented" role="group" aria-label="Rescuer status">
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

        <label className="visually-hidden" htmlFor="rescuer-zone">
          Filter by zone
        </label>
        <select
          id="rescuer-zone"
          className="select"
          style={{ height: 36, marginLeft: 'auto' }}
          value={zone}
          onChange={(event) => setZone(event.target.value)}
        >
          {data.zones.map((option) => (
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
                  <th scope="col">Rescuer</th>
                  <th scope="col">Zone</th>
                  <th scope="col">Status</th>
                  <th scope="col">Current Rescue</th>
                  <th scope="col">Completed</th>
                  <th scope="col">Reliability</th>
                  <th scope="col">Last Seen</th>
                  <th scope="col">
                    <span className="visually-hidden">Action</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {rows.length === 0 && (
                  <tr>
                    <td colSpan={8} className="t-body-sm muted dtable__empty">
                      No rescuers match this filter.
                    </td>
                  </tr>
                )}

                {rows.map((row) => (
                  <tr
                    key={row.id}
                    className={
                      row.id === selectedId ? 'dtable__row--on' : undefined
                    }
                    onClick={() => setSelectedId(row.id)}
                  >
                    <td>
                      <span className="partnercell">
                        <span className="avatar t-label-md" aria-hidden="true">
                          {row.initials}
                        </span>
                        <span style={{ minWidth: 0 }}>
                          <span
                            className="t-body-md"
                            style={{ fontWeight: 600 }}
                          >
                            {row.name}
                          </span>
                          <span className="dtable__sub t-body-sm muted">
                            ID: #{row.id}
                          </span>
                        </span>
                      </span>
                    </td>
                    <td className="t-body-sm">{row.zone}</td>
                    <td>
                      <span
                        className="dtable__state t-label-sm"
                        style={{ color: STATUS_COLOR[row.status] }}
                      >
                        <span
                          className={`dot${
                            row.status === 'on_rescue' ? ' dot--pulse' : ''
                          }`}
                          style={{ background: STATUS_COLOR[row.status] }}
                        />
                        {RESCUER_STATUS_LABEL[row.status]}
                      </span>
                    </td>
                    <td className="t-body-sm">
                      {row.currentRescueId ? (
                        <button
                          className="linkbtn t-label-md"
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            navigate(`/live-rescues/${row.currentRescueId}`);
                          }}
                        >
                          #{row.currentRescueId}
                        </button>
                      ) : (
                        <span className="muted">None</span>
                      )}
                    </td>
                    <td className="t-body-sm">{row.completed} completed</td>
                    <td className="t-body-sm">{row.reliability}</td>
                    <td className="t-body-sm muted">{row.lastSeen}</td>
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
              Showing {rows.length} of {data.totals.all} rescuers
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
                  <h2
                    className="t-headline-sm truncate"
                    style={{ margin: 0 }}
                  >
                    {selectedRow.name}
                  </h2>
                  <span
                    className="chip t-label-sm"
                    style={{
                      background:
                        selectedRow.verification === 'verified'
                          ? 'var(--primary-fixed)'
                          : 'var(--warning-bg)',
                      color:
                        selectedRow.verification === 'verified'
                          ? 'var(--on-primary-fixed)'
                          : VERIFICATION_COLOR[selectedRow.verification],
                    }}
                  >
                    <span
                      className="icon"
                      style={{ fontSize: 13 }}
                      aria-hidden="true"
                    >
                      {selectedRow.verification === 'verified'
                        ? 'verified'
                        : 'pending'}
                    </span>
                    {VERIFICATION_LABEL[selectedRow.verification]}
                  </span>
                </div>
                <span className="t-body-sm muted">
                  {dossier.joined} &middot; {dossier.transport}
                </span>
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
              <DossierStat
                label="Status"
                value={RESCUER_STATUS_LABEL[selectedRow.status]}
              />
              <DossierStat
                label="Completed"
                value={`${selectedRow.completed}`}
              />
              <DossierStat label="Reliability" value={selectedRow.reliability} />
              <DossierStat label="Last Seen" value={selectedRow.lastSeen} />
            </div>

            <div className="section-head">
              <h3
                className="t-headline-sm"
                style={{ margin: 0, fontSize: 15 }}
              >
                Rescuer Performance
              </h3>
              <span
                className="chip t-label-sm"
                style={{
                  background:
                    selectedRow.status === 'suspended'
                      ? 'var(--error-container)'
                      : 'var(--primary-fixed)',
                  color:
                    selectedRow.status === 'suspended'
                      ? 'var(--on-error-container)'
                      : 'var(--on-primary-fixed)',
                }}
              >
                {selectedRow.status === 'suspended'
                  ? 'Blocked'
                  : 'In good standing'}
              </span>
            </div>

            <dl className="factlist">
              <div className="factlist__row">
                <dt className="t-body-sm muted">Avg. Pickup Time</dt>
                <dd className="t-body-md">{dossier.avgPickupTime}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Acceptance Rate</dt>
                <dd className="t-body-md">{dossier.acceptanceRate}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Cancellations</dt>
                <dd className="t-body-md">{dossier.cancellations}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Distance Covered</dt>
                <dd className="t-body-md">{dossier.distance}</dd>
              </div>
            </dl>

            <div
              className={`alertcard ${
                selectedRow.status === 'suspended'
                  ? 'alertcard--error'
                  : selectedRow.verification === 'verified'
                    ? 'alertcard--good'
                    : 'alertcard--info'
              }`}
            >
              <span className="t-body-sm">{dossier.standing}</span>
            </div>

            <div className="section-head">
              <h3
                className="t-headline-sm"
                style={{ margin: 0, fontSize: 15 }}
              >
                Recent Activity
              </h3>
              <span className="t-label-sm muted dtable__state">
                <span
                  className="dot dot--pulse"
                  style={{ background: 'var(--success)' }}
                />
                Real-time sync
              </span>
            </div>

            <ol className="audit">
              {dossier.activity.map((entry) => (
                <li className="audit__row" key={`${entry.when}-${entry.title}`}>
                  <span className="audit__rail" aria-hidden="true">
                    <span
                      className="audit__dot"
                      style={{ background: 'var(--outline-variant)' }}
                    />
                  </span>
                  <div className="audit__body">
                    <div className="audit__title">
                      <span
                        className="t-body-md"
                        style={{ fontWeight: 600 }}
                      >
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
                        onClick={() =>
                          navigate(`/live-rescues/${entry.rescueId}`)
                        }
                      >
                        Open Rescue Detail &#8599;
                      </button>
                    )}
                  </div>
                </li>
              ))}
            </ol>

            <div className="controls" style={{ paddingTop: 0 }}>
              {selectedRow.currentRescueId ? (
                <button
                  className="btn btn--primary btn--block"
                  type="button"
                  onClick={() =>
                    navigate(`/live-rescues/${selectedRow.currentRescueId}`)
                  }
                >
                  <span
                    className="icon"
                    style={{ fontSize: 15 }}
                    aria-hidden="true"
                  >
                    cyclone
                  </span>
                  Open current rescue
                </button>
              ) : (
                <button
                  className="btn btn--quiet btn--block"
                  type="button"
                  onClick={() => navigate('/live-rescues')}
                >
                  <span
                    className="icon"
                    style={{ fontSize: 15 }}
                    aria-hidden="true"
                  >
                    cyclone
                  </span>
                  View live rescues
                </button>
              )}

              {/* Everything below changes what a real person is allowed to do.
                  None of it can be honest until the console API can carry the
                  decision and record who made it. */}
              {selectedRow.verification === 'pending' && (
                <button
                  className="btn btn--quiet btn--block"
                  type="button"
                  disabled
                  title="Approving verification needs the Phase 14 console API"
                >
                  Approve verification
                </button>
              )}
              <button
                className="btn btn--quiet btn--block"
                type="button"
                disabled
                title="Rescuer profile - not built yet"
              >
                View full rescuer profile
              </button>
              <button
                className={`btn btn--block ${
                  selectedRow.status === 'suspended'
                    ? 'btn--quiet'
                    : 'btn--danger'
                }`}
                type="button"
                disabled
                title="Suspension needs the Phase 14 console API"
              >
                {selectedRow.status === 'suspended'
                  ? 'Reinstate rescuer'
                  : 'Suspend rescuer'}
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
