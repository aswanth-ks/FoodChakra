import { useMemo, useState } from 'react';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import { SAMPLE_RECOVERY_PARTNERS } from './data/sampleZeroWaste';
import {
  RECOVERY_STATUS_LABEL,
  TIER_ORDER,
  type RecoveryPartnerDirectory,
  type RecoveryPartnerStatus,
  type RecoveryTier,
} from './data/zeroWasteTypes';
import { TierChip } from './components/ZeroWasteChrome';
import { TIER_COLOR } from './data/tierStyle';
import { SAMPLE_NETWORK_STATUS } from '../rescues/data/sampleRescues';
import type { NetworkStatus } from '../rescues/data/rescueTypes';

const STATUS_COLOR: Record<RecoveryPartnerStatus, string> = {
  accepting: 'var(--success)',
  at_capacity: 'var(--warning-deep)',
  offline: 'var(--on-surface-variant)',
};

type TierFilter = 'all' | RecoveryTier;

/**
 * "FoodLoop Waste Network Console - Recovery Partners".
 *
 * The facilities the fallback tier can actually send surplus to: which rung of
 * the hierarchy each sits on, what it will accept, and how much headroom it
 * has left today.
 *
 * Capacity is the column that matters most here, and it is why the page shows
 * a used/ceiling bar rather than a single number. A partner at 95% is
 * effectively unavailable for a large consignment even though it still reads
 * as "accepting", and routing has to see that before it promises a collection.
 *
 * **No Stitch design reached this session** - built from the console's own
 * tokens, reusing the Management directory shape.
 *
 * **Nothing here changes a partner.** Capacity ceilings, accepted categories
 * and availability are agreements with a real facility; they are disabled
 * pending the Phase 14 console API.
 */
export default function RecoveryPartnersPage({
  data = SAMPLE_RECOVERY_PARTNERS,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: RecoveryPartnerDirectory;
  status?: NetworkStatus;
}) {
  const [tier, setTier] = useState<TierFilter>('all');
  const [search, setSearch] = useState('');
  const [zone, setZone] = useState(data.zones[0] ?? 'All Zones');
  const [selectedId, setSelectedId] = useState<string | null>(
    data.rows[0]?.id ?? null,
  );

  const rows = useMemo(() => {
    const query = search.trim().toLowerCase();
    return data.rows.filter((row) => {
      const matchesTier = tier === 'all' || row.tier === tier;
      const matchesZone = zone === data.zones[0] || row.zone === zone;
      const matchesQuery =
        query.length === 0 ||
        row.name.toLowerCase().includes(query) ||
        row.id.toLowerCase().includes(query) ||
        row.accepts.some((entry) => entry.toLowerCase().includes(query));
      return matchesTier && matchesZone && matchesQuery;
    });
  }, [data.rows, data.zones, tier, zone, search]);

  const selectedRow = data.rows.find((row) => row.id === selectedId) ?? null;
  const detail = selectedId ? data.details[selectedId] : undefined;

  /** Only the tiers a recovery partner can actually sit on. */
  const partnerTiers = TIER_ORDER.filter(
    (entry) => entry !== 'human' && entry !== 'landfill',
  );

  const totalHeadroom = data.rows
    .filter((row) => row.status === 'accepting')
    .reduce((sum, row) => sum + (row.capacityKg - row.usedKg), 0);

  return (
    <ConsoleLayout
      title="Recovery Partners"
      subtitle={`${data.totals.accepting} accepting`}
      statusStrip={
        <ConsoleStatusStrip
          activeRescues={status.activeRescues}
          needIntervention={data.totals.offline}
          version={status.consoleVersion}
        />
      }
    >
      <nav className="crumbs t-body-sm" aria-label="Breadcrumb">
        <span className="muted">Zero-Waste Network</span>
        <span aria-hidden="true">&rsaquo;</span>
        <span className="muted">Recovery Partners</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">Recovery Partners</h1>
          <p className="t-body-md">
            Where the fallback tier can send surplus: the rung each facility
            sits on, what it accepts, and how much headroom is left today.
          </p>
        </div>
        <div className="intro__actions">
          <span className="pill t-label-sm">
            <span
              className="dot dot--pulse"
              style={{ background: 'var(--success)' }}
            />
            {totalHeadroom.toLocaleString()} kg headroom
          </span>
          <button
            className="btn btn--primary"
            type="button"
            disabled
            title="Onboarding a recovery partner needs the Phase 14 console API"
          >
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              add_business
            </span>
            Add partner
          </button>
        </div>
      </section>


      <section className="kpis" aria-label="Recovery partner totals">
        <PartnerKpi
          label="Partners"
          icon="factory"
          value={`${data.totals.all}`}
          caption="Registered recovery facilities"
        />
        <PartnerKpi
          label="Accepting"
          icon="check_circle"
          value={`${data.totals.accepting}`}
          caption="Taking loads right now"
          color="var(--success)"
        />
        <PartnerKpi
          label="At Capacity"
          icon="do_not_disturb_on"
          value={`${data.totals.atCapacity}`}
          caption="Daily ceiling reached"
          color="var(--warning-deep)"
        />
        <PartnerKpi
          label="Offline"
          icon="power_off"
          value={`${data.totals.offline}`}
          caption="Unavailable to routing"
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
            placeholder="Search partners, IDs, or categories"
            aria-label="Search recovery partners"
            style={{ paddingRight: 12 }}
          />
        </div>

        <div className="segmented" role="group" aria-label="Recovery tier">
          <button
            type="button"
            aria-pressed={tier === 'all'}
            className={`segmented__btn t-label-md${
              tier === 'all' ? ' segmented__btn--on' : ''
            }`}
            onClick={() => setTier('all')}
          >
            All tiers
          </button>
          {partnerTiers.map((entry) => (
            <button
              key={entry}
              type="button"
              aria-pressed={tier === entry}
              className={`segmented__btn t-label-md${
                tier === entry ? ' segmented__btn--on' : ''
              }`}
              onClick={() => setTier(entry)}
            >
              {RECOVERY_TIER_TAB[entry]}
            </button>
          ))}
        </div>

        <label className="visually-hidden" htmlFor="recovery-zone">
          Filter by zone
        </label>
        <select
          id="recovery-zone"
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

      <section className={`queuesplit${detail ? '' : ' queuesplit--wide'}`}>
        <div className="card">
          <div className="tablewrap">
            <table className="dtable">
              <thead>
                <tr>
                  <th scope="col">Facility</th>
                  <th scope="col">Tier</th>
                  <th scope="col">Zone</th>
                  <th scope="col">Status</th>
                  <th scope="col">Capacity Today</th>
                  <th scope="col">Accepts</th>
                </tr>
              </thead>
              <tbody>
                {rows.length === 0 && (
                  <tr>
                    <td colSpan={6} className="t-body-sm muted dtable__empty">
                      No recovery partners match this filter.
                    </td>
                  </tr>
                )}

                {rows.map((row) => {
                  const used = Math.min(
                    100,
                    Math.round((row.usedKg / row.capacityKg) * 100),
                  );
                  const tight = used >= 90;
                  return (
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
                            <span className="t-body-md" style={{ fontWeight: 600 }}>
                              {row.name}
                            </span>
                            <span className="dtable__sub t-body-sm muted">
                              {row.id} &middot; {row.hours}
                            </span>
                          </span>
                        </span>
                      </td>
                      <td>
                        <TierChip tier={row.tier} short />
                      </td>
                      <td className="t-body-sm">{row.zone}</td>
                      <td>
                        <span
                          className="dtable__state t-label-sm"
                          style={{ color: STATUS_COLOR[row.status] }}
                        >
                          <span
                            className={`dot${
                              row.status === 'accepting' ? ' dot--pulse' : ''
                            }`}
                            style={{ background: STATUS_COLOR[row.status] }}
                          />
                          {RECOVERY_STATUS_LABEL[row.status]}
                        </span>
                      </td>
                      <td style={{ minWidth: 160 }}>
                        <span
                          className="t-body-sm"
                          style={{
                            display: 'block',
                            marginBottom: 4,
                            color: tight ? 'var(--warning-deep)' : undefined,
                            fontWeight: tight ? 600 : undefined,
                          }}
                        >
                          {row.usedKg.toLocaleString()} /{' '}
                          {row.capacityKg.toLocaleString()} kg
                        </span>
                        <span className="progress" style={{ display: 'block' }}>
                          <span
                            className="progress__fill"
                            style={{
                              width: `${used}%`,
                              background: tight
                                ? 'var(--warning-deep)'
                                : TIER_COLOR[row.tier],
                            }}
                          />
                        </span>
                      </td>
                      <td className="t-body-sm muted">
                        {row.accepts.join(', ')}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <div className="queue__foot t-body-sm">
            <span>
              Showing {rows.length} of {data.totals.all} partners
            </span>
            <span className="t-label-sm muted">
              Capacity resets at each facility&rsquo;s opening hour
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
                  <TierChip tier={selectedRow.tier} short />
                </div>
                <span className="t-body-sm muted">
                  {selectedRow.id} &middot; {selectedRow.zone} &middot;{' '}
                  {selectedRow.hours}
                </span>
              </div>
              <button
                className="iconbtn"
                type="button"
                onClick={() => setSelectedId(null)}
                aria-label="Close partner detail"
              >
                <span className="icon" style={{ fontSize: 18 }}>
                  close
                </span>
              </button>
            </div>

            <div
              className={`alertcard ${
                selectedRow.status === 'accepting'
                  ? 'alertcard--good'
                  : selectedRow.status === 'at_capacity'
                    ? 'alertcard--info'
                    : 'alertcard--neutral'
              }`}
            >
              <span className="t-body-sm">{detail.note}</span>
            </div>

            <div className="statgrid">
              <Stat
                label="Taken Today"
                value={`${selectedRow.usedKg.toLocaleString()} kg`}
              />
              <Stat
                label="Daily Ceiling"
                value={`${selectedRow.capacityKg.toLocaleString()} kg`}
              />
              <Stat
                label="Headroom"
                value={`${Math.max(
                  0,
                  selectedRow.capacityKg - selectedRow.usedKg,
                ).toLocaleString()} kg`}
              />
              <Stat
                label="Trailing 30d"
                value={`${selectedRow.lifetimeKg.toLocaleString()} kg`}
              />
            </div>

            <div className="section-head">
              <h3 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                Acceptance Rules
              </h3>
            </div>

            <dl className="factlist">
              <div className="factlist__row">
                <dt className="t-body-sm muted">Accepts</dt>
                <dd className="t-body-md">{selectedRow.accepts.join(', ')}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Excludes</dt>
                <dd className="t-body-md">{detail.excludes.join(', ')}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Permit</dt>
                <dd className="t-body-md">{detail.licence}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Turnaround</dt>
                <dd className="t-body-md">{detail.turnaround}</dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Contact</dt>
                <dd className="t-body-md">{detail.contact}</dd>
              </div>
            </dl>

            <div className="section-head">
              <h3 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                Recent Intake
              </h3>
            </div>

            <ol className="audit">
              {detail.activity.map((entry) => (
                <li className="audit__row" key={`${entry.when}-${entry.title}`}>
                  <span className="audit__rail" aria-hidden="true">
                    <span
                      className="audit__dot"
                      style={{ background: TIER_COLOR[selectedRow.tier] }}
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
                    {entry.kg > 0 && (
                      <div className="t-label-sm">{entry.kg} kg</div>
                    )}
                  </div>
                </li>
              ))}
            </ol>

            <div className="controls" style={{ paddingTop: 0 }}>
              {/* Each of these is an agreement with a real facility. */}
              <button
                className="btn btn--quiet btn--block"
                type="button"
                disabled
                title="Editing capacity needs the Phase 14 console API"
              >
                Edit capacity and hours
              </button>
              <button
                className="btn btn--quiet btn--block"
                type="button"
                disabled
                title="Editing acceptance rules needs the Phase 14 console API"
              >
                Edit acceptance rules
              </button>
              <button
                className={`btn btn--block ${
                  selectedRow.status === 'offline' ? 'btn--quiet' : 'btn--danger'
                }`}
                type="button"
                disabled
                title="Changing availability needs the Phase 14 console API"
              >
                {selectedRow.status === 'offline'
                  ? 'Bring partner back online'
                  : 'Take partner offline'}
              </button>
            </div>
          </aside>
        )}
      </section>
    </ConsoleLayout>
  );
}

/** Tab labels for the tiers a recovery partner can sit on. */
const RECOVERY_TIER_TAB: Record<RecoveryTier, string> = {
  human: 'Human',
  animal_feed: 'Animal Feed',
  composting: 'Composting',
  energy: 'Energy',
  landfill: 'Landfill',
};

function PartnerKpi({
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
          style={{ fontSize: 32, lineHeight: '40px', color, fontWeight: 700 }}
        >
          {value}
        </span>
      </div>
      <div className="kpi__foot t-body-sm truncate">{caption}</div>
    </article>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="statgrid__cell">
      <span className="t-label-sm upper muted">{label}</span>
      <span className="t-body-md truncate" style={{ fontWeight: 600 }}>
        {value}
      </span>
    </div>
  );
}
