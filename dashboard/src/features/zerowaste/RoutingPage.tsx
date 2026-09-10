import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import { SAMPLE_ROUTING_POLICY } from './data/sampleZeroWaste';
import {
  TIER_LABEL,
  TIER_ORDER,
  type RoutingPolicy,
  type RoutingRule,
} from './data/zeroWasteTypes';
import { TierChip } from './components/ZeroWasteChrome';
import { TIER_COLOR } from './data/tierStyle';
import { SAMPLE_NETWORK_STATUS } from '../rescues/data/sampleRescues';
import type { NetworkStatus } from '../rescues/data/rescueTypes';

/**
 * "FoodLoop Zero-Waste Network Console - Routing".
 *
 * The policy that decides where a fallback case goes: an ordered rule list,
 * and a preview of what that list does to the cases currently in hand.
 *
 * Two things drive the design.
 *
 * **Order is the policy.** These rules are evaluated top-down and the first
 * match wins, so a rule's position is as meaningful as its condition. The list
 * therefore always renders in priority order and shows the number - it is not
 * a set of independent toggles, and presenting it as one would hide the single
 * most important property of the configuration.
 *
 * **The preview is the point.** A rule list on its own is unreadable; what an
 * operator needs is "given these rules, where does each case in hand actually
 * end up". The preview table answers exactly that, and flags the cases no rule
 * could place - the ones that become landfill.
 *
 * **No Stitch design reached this session** - built from the console's own
 * tokens and primitives.
 *
 * **Nothing here is editable.** These rules decide where real food goes;
 * changing one changes the destination of every future case, so editing,
 * reordering and disabling all need the Phase 14 console API, which is also
 * the only thing that can record who changed the policy and when.
 */
export default function RoutingPage({
  data = SAMPLE_ROUTING_POLICY,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: RoutingPolicy;
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();

  const [selectedId, setSelectedId] = useState<string | null>(
    data.rules[0]?.id ?? null,
  );

  const selected =
    data.rules.find((rule) => rule.id === selectedId) ?? null;

  /** Always priority order - the order is the policy. */
  const rules = [...data.rules].sort((a, b) => a.priority - b.priority);

  const placed = data.preview.filter((row) => row.placed).length;

  return (
    <ConsoleLayout
      title="Routing"
      subtitle={`${data.rules.length} rules`}
      statusStrip={
        <ConsoleStatusStrip
          activeRescues={status.activeRescues}
          needIntervention={data.unplacedCount}
          version={status.consoleVersion}
        />
      }
    >
      <nav className="crumbs t-body-sm" aria-label="Breadcrumb">
        <span className="muted">Zero-Waste Network</span>
        <span aria-hidden="true">&rsaquo;</span>
        <span className="muted">Routing</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">Routing</h1>
          <p className="t-body-md">
            The policy that decides where fallback surplus goes. Rules are
            evaluated top down and the first match wins, so position matters as
            much as condition.
          </p>
        </div>
        <div className="intro__actions">
          <span className="pill t-label-sm">
            <span
              className="dot dot--pulse"
              style={{ background: 'var(--success)' }}
            />
            {data.autoRoutedShare}% routed automatically
          </span>
          <span className="t-label-sm muted">{data.window}</span>
          <button
            className="btn btn--primary"
            type="button"
            disabled
            title="Editing routing policy needs the Phase 14 console API"
          >
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              edit
            </span>
            Edit policy
          </button>
        </div>
      </section>


      <section className="kpis" aria-label="Routing totals">
        <RoutingKpi
          label="Auto-Routed"
          icon="alt_route"
          value={`${data.autoRoutedShare}%`}
          caption="Placed with no operator involved"
          color="var(--success)"
        />
        <RoutingKpi
          label="Manual"
          icon="pan_tool"
          value={`${data.manualCount}`}
          caption="Needed an operator decision"
          color="var(--warning-deep)"
        />
        <RoutingKpi
          label="Unplaced"
          icon="block"
          value={`${data.unplacedCount}`}
          caption="No rule could place them"
          color="var(--error)"
        />
        <RoutingKpi
          label="Active Rules"
          icon="rule"
          value={`${rules.filter((rule) => rule.enabled).length} / ${rules.length}`}
          caption="Evaluated in priority order"
        />
      </section>

      <section className="queuesplit">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          {/* The ordered rule list. */}
          <div className="card">
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                  Routing Rules
                </h2>
                <span className="t-body-sm muted">
                  Evaluated top down &mdash; the first match wins
                </span>
              </div>
              <span className="t-label-sm muted">{data.window}</span>
            </div>

            <div className="tablewrap">
              <table className="dtable">
                <thead>
                  <tr>
                    <th scope="col">#</th>
                    <th scope="col">Rule</th>
                    <th scope="col">Destination</th>
                    <th scope="col">Matches</th>
                    <th scope="col">State</th>
                  </tr>
                </thead>
                <tbody>
                  {rules.map((rule) => (
                    <tr
                      key={rule.id}
                      className={
                        rule.id === selectedId ? 'dtable__row--on' : undefined
                      }
                      onClick={() => setSelectedId(rule.id)}
                    >
                      <td>
                        <span className="ranked__num t-label-md">
                          {rule.priority}
                        </span>
                      </td>
                      <td>
                        <span style={{ minWidth: 0 }}>
                          <span className="t-body-md" style={{ fontWeight: 600 }}>
                            {rule.name}
                          </span>
                          <span className="dtable__sub t-body-sm muted">
                            {rule.condition}
                          </span>
                        </span>
                      </td>
                      <td>
                        <TierChip tier={rule.destination} short />
                      </td>
                      <td className="t-body-sm">{rule.matches}</td>
                      <td>
                        <span
                          className="dtable__state t-label-sm"
                          style={{
                            color: rule.enabled
                              ? 'var(--success)'
                              : 'var(--on-surface-variant)',
                          }}
                        >
                          <span
                            className="dot"
                            style={{
                              background: rule.enabled
                                ? 'var(--success)'
                                : 'var(--outline-variant)',
                            }}
                          />
                          {rule.enabled ? 'Active' : 'Disabled'}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <p className="levels__note t-body-sm">
              Reordering is not offered here. Moving a rule changes the
              destination of every future case, so it needs the Phase 14 console
              API &mdash; which is also the only thing that can record who
              changed the policy.
            </p>
          </div>

          {/* What the rules do to the cases in hand. */}
          <div className="card">
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                  Routing Preview
                </h2>
                <span className="t-body-sm muted">
                  Where the current rules send the cases in hand
                </span>
              </div>
              <span
                className="chip t-label-sm"
                style={{
                  background:
                    placed === data.preview.length
                      ? 'var(--primary-fixed)'
                      : 'var(--error-container)',
                  color:
                    placed === data.preview.length
                      ? 'var(--on-primary-fixed)'
                      : 'var(--on-error-container)',
                }}
              >
                {placed} of {data.preview.length} placed
              </span>
            </div>

            <div className="tablewrap">
              <table className="dtable">
                <thead>
                  <tr>
                    <th scope="col">Case</th>
                    <th scope="col">Category</th>
                    <th scope="col">Matched By</th>
                    <th scope="col">Destination</th>
                    <th scope="col">Partner</th>
                  </tr>
                </thead>
                <tbody>
                  {data.preview.map((row) => (
                    <tr
                      key={row.caseId}
                      onClick={() =>
                        navigate(`/zero-waste/fallback/${row.caseId}`)
                      }
                    >
                      <td>
                        <span style={{ minWidth: 0 }}>
                          <span className="t-body-md" style={{ fontWeight: 600 }}>
                            {row.caseId}
                          </span>
                          <span className="dtable__sub t-body-sm muted">
                            {row.surplus} &middot; {row.kg} kg
                          </span>
                        </span>
                      </td>
                      <td className="t-body-sm">{row.category}</td>
                      <td>
                        <button
                          className="linkbtn t-label-md"
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            setSelectedId(row.ruleId);
                          }}
                        >
                          {row.ruleId}
                        </button>
                      </td>
                      <td>
                        <TierChip tier={row.destination} short />
                      </td>
                      <td className="t-body-sm">
                        {row.placed ? (
                          <span className="muted">{row.partner}</span>
                        ) : (
                          <span
                            className="dtable__state t-label-sm"
                            style={{ color: 'var(--error)' }}
                          >
                            <span
                              className="dot"
                              style={{ background: 'var(--error)' }}
                            />
                            {row.partner}
                          </span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {placed < data.preview.length && (
              <div className="alertcard alertcard--error">
                <span className="t-body-sm">
                  <strong>
                    {data.preview.length - placed} case
                    {data.preview.length - placed === 1 ? '' : 's'} cannot be
                    placed.
                  </strong>{' '}
                  Nothing above landfill will take them before their window
                  closes. Every one of these is worth reviewing &mdash; either a
                  rule is too narrow, or the network is short a partner in that
                  zone.
                </span>
              </div>
            )}
          </div>

          {/* Destination spread. */}
          <div className="card">
            <div className="section-head">
              <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                Where Rules Send Volume
              </h2>
              <span className="t-label-sm muted">
                Matches per destination, {data.window.toLowerCase()}
              </span>
            </div>

            <ol className="funnel">
              {TIER_ORDER.map((tier) => {
                const matches = rules
                  .filter((rule) => rule.destination === tier)
                  .reduce((sum, rule) => sum + rule.matches, 0);
                return (
                  <li className="funnel__stage" key={tier}>
                    <span
                      className="t-label-sm upper"
                      style={{ color: TIER_COLOR[tier] }}
                    >
                      {TIER_LABEL[tier]}
                    </span>
                    <span
                      className="t-metric"
                      style={{
                        fontSize: 24,
                        lineHeight: '30px',
                        fontWeight: 700,
                      }}
                    >
                      {matches}
                    </span>
                    <span className="t-label-sm muted">matches</span>
                  </li>
                );
              })}
            </ol>
          </div>
        </div>

        {/* Rule inspection. */}
        {selected && (
          <aside className="card" aria-label={`Rule ${selected.id}`}>
            <RuleInspector rule={selected} onClose={() => setSelectedId(null)} />
          </aside>
        )}
      </section>
    </ConsoleLayout>
  );
}

function RuleInspector({
  rule,
  onClose,
}: {
  rule: RoutingRule;
  onClose: () => void;
}) {
  return (
    <>
      <div className="section-head">
        <div style={{ minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <h2 className="t-headline-sm truncate" style={{ margin: 0 }}>
              {rule.name}
            </h2>
            <span className="chip t-label-sm">Priority {rule.priority}</span>
          </div>
          <span className="t-body-sm muted">{rule.id}</span>
        </div>
        <button
          className="iconbtn"
          type="button"
          onClick={onClose}
          aria-label="Close rule detail"
        >
          <span className="icon" style={{ fontSize: 18 }}>
            close
          </span>
        </button>
      </div>

      <div className="alertcard alertcard--info">
        <span className="t-body-sm">{rule.rationale}</span>
      </div>

      <div className="statgrid">
        <Stat label="Destination" value={TIER_LABEL[rule.destination]} />
        <Stat label="Priority" value={`${rule.priority}`} />
        <Stat label="Matches" value={`${rule.matches}`} />
        <Stat label="State" value={rule.enabled ? 'Active' : 'Disabled'} />
      </div>

      <div className="section-head">
        <h3 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
          Condition
        </h3>
      </div>

      <dl className="factlist">
        <div className="factlist__row">
          <dt className="t-body-sm muted">Matches when</dt>
          <dd className="t-body-md">{rule.condition}</dd>
        </div>
        <div className="factlist__row">
          <dt className="t-body-sm muted">Sends to</dt>
          <dd className="t-body-md">
            <TierChip tier={rule.destination} />
          </dd>
        </div>
      </dl>

      <div className="controls" style={{ paddingTop: 0 }}>
        {/* Every one of these changes where real food goes. */}
        <button
          className="btn btn--quiet btn--block"
          type="button"
          disabled
          title="Editing a rule needs the Phase 14 console API"
        >
          Edit condition
        </button>
        <button
          className="btn btn--quiet btn--block"
          type="button"
          disabled
          title="Reordering rules needs the Phase 14 console API"
        >
          Change priority
        </button>
        <button
          className="btn btn--danger btn--block"
          type="button"
          disabled
          title="Disabling a rule needs the Phase 14 console API"
        >
          Disable rule
        </button>
      </div>
    </>
  );
}

function RoutingKpi({
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
