import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import OperationsMap from './components/OperationsMap';
import {
  SEVERITY_COLOR,
  SEVERITY_ICON,
  SEVERITY_LABEL,
} from './data/severity';
import {
  SAMPLE_NETWORK_STATUS,
  SAMPLE_RESCUES,
} from './data/sampleRescues';
import {
  formatRemaining,
  type NetworkStatus,
  type RescueSeverity,
  type RescueSummary,
} from './data/rescueTypes';

/** The map's three filter tabs. */
type MapFilter = 'all' | 'attention' | 'critical';

/** The side panel's four filter pills. */
type PanelFilter = 'all' | 'critical' | 'attention' | 'healthy';

/**
 * "FoodLoop Rescue Operations Console — Live Rescue Map".
 *
 * Faithful translation of the Stitch design
 * (screen `a09ee9419df34806981f38b776c5b172`).
 *
 * The monitoring board: the operational map on the left, and the active
 * rescue list with the selected rescue's detail on the right.
 *
 * **Design divergence:** the mock carries a generic mobile app bar titled
 * "Item Details" — a leftover from its template — which is omitted, as it was
 * on the mobile Activity screen. The page takes its heading from the console
 * layout like every other console page.
 */
export default function LiveRescueMapPage({
  rescues = SAMPLE_RESCUES,
  status = SAMPLE_NETWORK_STATUS,
}: {
  rescues?: RescueSummary[];
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();

  const [mapFilter, setMapFilter] = useState<MapFilter>('all');
  const [panelFilter, setPanelFilter] = useState<PanelFilter>('all');
  const [search, setSearch] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(
    rescues[0]?.id ?? null,
  );

  const counts = useMemo(() => countBySeverity(rescues), [rescues]);

  const mapRescues = useMemo(
    () =>
      rescues.filter((rescue) =>
        mapFilter === 'all' ? true : rescue.severity === mapFilter,
      ),
    [rescues, mapFilter],
  );

  const listRescues = useMemo(() => {
    const query = search.trim().toLowerCase();
    return rescues.filter((rescue) => {
      const matchesFilter =
        panelFilter === 'all'
          ? true
          : panelFilter === 'healthy'
            ? rescue.severity === 'active' || rescue.severity === 'completed'
            : rescue.severity === panelFilter;

      const matchesQuery =
        query.length === 0 ||
        rescue.partner.toLowerCase().includes(query) ||
        rescue.id.toLowerCase().includes(query);

      return matchesFilter && matchesQuery;
    });
  }, [rescues, panelFilter, search]);

  const selected =
    rescues.find((rescue) => rescue.id === selectedId) ?? listRescues[0] ?? null;

  return (
    <ConsoleLayout
      title="Live Rescue Map"
      subtitle="Monitor active rescues and network conditions"
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
          <h1 className="t-headline-lg" style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            Live Rescue Map
            <span
              className="chip t-label-sm"
              style={{
                background: 'var(--primary-fixed)',
                color: 'var(--on-primary-fixed)',
              }}
            >
              <span className="dot dot--pulse" style={{ background: 'var(--success)' }} />
              Live
            </span>
          </h1>
          <p className="t-body-md">
            Monitor active rescues, pickup progress, and network conditions in
            real time.
          </p>
        </div>
      </section>

      <section className="mapsplit">
        <div className="card opsmap">
          <div className="opsmap__head">
            <div className="segmented" role="tablist" aria-label="Map filter">
              {(['all', 'attention', 'critical'] as MapFilter[]).map((filter) => (
                <button
                  key={filter}
                  type="button"
                  role="tab"
                  aria-selected={mapFilter === filter}
                  className={`segmented__btn t-label-md${
                    mapFilter === filter ? ' segmented__btn--on' : ''
                  }`}
                  onClick={() => setMapFilter(filter)}
                >
                  {filter === 'all'
                    ? 'All rescues'
                    : filter === 'attention'
                      ? 'Attention'
                      : 'Critical'}
                </button>
              ))}
            </div>
          </div>

          <OperationsMap
            rescues={mapRescues}
            selectedId={selected?.id ?? null}
            onSelect={setSelectedId}
          />

          <div className="opsmap__summary">
            <SummaryCell
              label="REGION COVERAGE"
              value={status.regionCoverage}
              icon="analytics"
            />
            <SummaryCell
              label="AVG DISPATCH TIME"
              value={status.avgDispatch}
              icon="timer"
            />
            <SummaryCell
              label="RESCUERS ACTIVE"
              value={status.rescuersOnline}
              icon="group"
            />
          </div>
        </div>

        <div className="card rescuepanel">
          <div className="section-head">
            <div>
              <h2 className="t-headline-sm" style={{ margin: 0 }}>
                Active Rescues
              </h2>
              <span className="t-body-sm muted">{status.activeRescues} active</span>
            </div>
            {/* Filtering beyond the pills needs the Phase 14 console API. */}
            <button className="toolbtn t-label-md" type="button" disabled>
              <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
                filter_list
              </span>
              Filter
            </button>
          </div>

          <div className="rescuepanel__controls">
            <div className="topbar__search" style={{ maxWidth: 'none' }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                search
              </span>
              <input
                type="search"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder="Search rescues or partners"
                aria-label="Search active rescues"
                style={{ paddingRight: 12 }}
              />
            </div>

            <div className="pillrow">
              {(['all', 'critical', 'attention', 'healthy'] as PanelFilter[]).map(
                (filter) => (
                  <button
                    key={filter}
                    type="button"
                    aria-pressed={panelFilter === filter}
                    className={`filterpill t-label-sm${
                      panelFilter === filter ? ' filterpill--on' : ''
                    }`}
                    onClick={() => setPanelFilter(filter)}
                  >
                    {filter === 'all'
                      ? 'All'
                      : filter === 'healthy'
                        ? 'Healthy'
                        : `${SEVERITY_LABEL[filter]} (${counts[filter]})`}
                  </button>
                ),
              )}
            </div>
          </div>

          {selected && (
            <div
              className={`focuscard focuscard--${selected.severity}`}
              aria-label={`Selected rescue: ${selected.partner}`}
            >
              <div className="focuscard__tags">
                <span
                  className="chip t-label-sm"
                  style={{
                    background:
                      selected.severity === 'critical'
                        ? 'var(--error-container)'
                        : 'var(--warning-bg)',
                    color:
                      selected.severity === 'critical'
                        ? 'var(--on-error-container)'
                        : 'var(--warning-deep)',
                  }}
                >
                  {selected.severity === 'critical'
                    ? 'Critical Focus'
                    : `${SEVERITY_LABEL[selected.severity]} Focus`}
                </span>
                <span className="t-label-sm upper muted">
                  Rescue state: searching
                </span>
              </div>

              <div className="t-headline-sm">{selected.partner}</div>
              <div className="t-body-sm muted">{selected.locality}</div>

              <div className="focuscard__facts">
                <Fact label="QUANTITY" value={selected.quantityLabel} />
                <Fact
                  label="TIME REMAINING"
                  value={`${selected.minutesRemaining} min`}
                  accent={SEVERITY_COLOR[selected.severity]}
                />
              </div>
              <Fact label="PICKUP WINDOW" value="Today · 1:30 PM – 2:00 PM" />

              {selected.severity !== 'active' && (
                <div className="focuscard__alert t-body-sm">
                  <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                    warning
                  </span>
                  Operational status: Rescue escalation active
                </div>
              )}

              <div className="focuscard__actions">
                <button
                  className="btn btn--quiet"
                  type="button"
                  onClick={() => navigate(`/live-rescues/${selected.id}`)}
                >
                  <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                    open_in_new
                  </span>
                  Open Rescue
                </button>
                <button
                  className="btn btn--danger"
                  type="button"
                  onClick={() =>
                    navigate(`/live-rescues/${selected.id}?intervene=1`)
                  }
                >
                  <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                    bolt
                  </span>
                  Intervene
                </button>
              </div>
            </div>
          )}

          <div className="rescuepanel__list">
            {listRescues.length === 0 && (
              <p className="t-body-sm muted" style={{ padding: '16px' }}>
                No rescues match this filter.
              </p>
            )}

            {listRescues.map((rescue) => (
              <button
                key={rescue.id}
                type="button"
                className={`rescuerow${
                  rescue.id === selected?.id ? ' rescuerow--on' : ''
                }`}
                onClick={() => setSelectedId(rescue.id)}
              >
                <span
                  className="rescuerow__icon icon"
                  style={{ color: SEVERITY_COLOR[rescue.severity] }}
                  aria-hidden="true"
                >
                  {SEVERITY_ICON[rescue.severity]}
                </span>
                <span className="rescuerow__body">
                  <span className="t-body-md truncate" style={{ fontWeight: 600 }}>
                    {rescue.partner}
                  </span>
                  <span className="t-body-sm muted truncate">
                    {rescue.quantityLabel} · {formatRemaining(rescue.minutesRemaining)}
                  </span>
                </span>
                <span
                  className="chip t-label-sm"
                  style={{
                    background: 'var(--surface-container-low)',
                    color: SEVERITY_COLOR[rescue.severity],
                    flexShrink: 0,
                  }}
                >
                  {SEVERITY_LABEL[rescue.severity]}
                </span>
              </button>
            ))}
          </div>
        </div>
      </section>
    </ConsoleLayout>
  );
}

function countBySeverity(rescues: RescueSummary[]): Record<RescueSeverity, number> {
  const counts: Record<RescueSeverity, number> = {
    critical: 0,
    attention: 0,
    active: 0,
    completed: 0,
  };
  for (const rescue of rescues) counts[rescue.severity] += 1;
  return counts;
}

function Fact({
  label,
  value,
  accent,
}: {
  label: string;
  value: string;
  accent?: string;
}) {
  return (
    <div>
      <div className="t-label-sm upper muted">{label}</div>
      <div className="t-body-md" style={{ fontWeight: 600, color: accent }}>
        {value}
      </div>
    </div>
  );
}

function SummaryCell({
  label,
  value,
  icon,
}: {
  label: string;
  value: string;
  icon: string;
}) {
  return (
    <div className="opsmap__summarycell">
      <div>
        <div className="t-label-sm upper muted">{label}</div>
        <div className="t-metric" style={{ fontSize: 18, color: 'var(--primary)' }}>
          {value}
        </div>
      </div>
      <span className="icon muted" style={{ fontSize: 20 }} aria-hidden="true">
        {icon}
      </span>
    </div>
  );
}
