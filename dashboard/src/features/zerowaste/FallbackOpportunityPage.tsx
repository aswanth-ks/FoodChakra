import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import { SAMPLE_FALLBACK_OPPORTUNITY } from './data/sampleFallback';
import type { FallbackOpportunity, PathwayState } from './data/fallbackTypes';
import { TierChip } from './components/ZeroWasteChrome';
import { SAMPLE_NETWORK_STATUS } from '../rescues/data/sampleRescues';
import type { NetworkStatus } from '../rescues/data/rescueTypes';
import '../../styles/fallback.css';

/** Status-pill colour per pathway state, following the design's treatment. */
const STATE_STYLE: Record<PathwayState, { bg: string; fg: string }> = {
  recommended: { bg: 'var(--primary-fixed)', fg: 'var(--on-primary-fixed)' },
  available: { bg: 'var(--surface-container)', fg: 'var(--on-surface-variant)' },
  limited: { bg: 'var(--warning-bg)', fg: 'var(--warning-deep)' },
  check: { bg: 'var(--warning-bg)', fg: 'var(--warning-deep)' },
};

/**
 * "FoodLoop Zero-Waste Network Console - Fallback Opportunity".
 *
 * Faithful translation of the Stitch design
 * (screen `a75b3478a61043db95d66ff928a1c838`), fetched from the Stitch project
 * and followed section by section: the surplus banner with its countdown, the
 * surplus inventory profile, the four recovery pathways, the recommendation
 * analysis, the partner shortlist, the chain-of-custody routing strip, the
 * operator decision panel, the fallback activity trail, and the cancellation
 * dialog.
 *
 * The screen is a decision, and it is built as one: choosing a **pathway**
 * filters the **partners**, choosing a partner completes the **routing**
 * strip, and the handoff stays unavailable until both are settled. That chain
 * is why the partner list and routing strip react to the selection rather than
 * standing as static panels.
 *
 * **Design divergences**, all deliberate:
 *
 * 1. The mock is drawn on the mobile brand surface and redraws its own
 *    sidebar. This uses the console's palette and the shared `ConsoleLayout`,
 *    as every console page translated from a Mobile Design System screen has.
 * 2. The mock names the origin rescue `FL-20481`, which in this console is the
 *    rescue Amara Okonkwo is currently carrying. A rescue cannot be both in
 *    progress and failed, so the origin is `FL-20470` - the dispatch that
 *    actually failed, per Activity Log entry `EV-90390`.
 * 3. The mock lists Animal-Feed Recovery last, below composting and biogas.
 *    That is not the food-use hierarchy order the rest of this module enforces
 *    (feed outranks both). The cards render in the design's order, but
 *    selecting a pathway below the recommended tier raises the same warning
 *    the module raises everywhere else, so the ordering cannot quietly cost a
 *    rung.
 *
 * **Nothing here dispatches.** Creating a handoff sends a real vehicle to a
 * real address; every action reports what it would do, pending Phase 14.
 */
export default function FallbackOpportunityPage({
  data = SAMPLE_FALLBACK_OPPORTUNITY,
  status = SAMPLE_NETWORK_STATUS,
}: {
  data?: FallbackOpportunity;
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();
  const { id } = useParams();

  const [pathwayId, setPathwayId] = useState(data.recommendedPathwayId);
  const [partnerId, setPartnerId] = useState<string | null>(null);
  const [showPartners, setShowPartners] = useState(false);
  const [confirmCancel, setConfirmCancel] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  const pathway =
    data.pathways.find((entry) => entry.id === pathwayId) ?? data.pathways[0];
  const recommended = data.pathways.find(
    (entry) => entry.id === data.recommendedPathwayId,
  );

  // Partners are the ones that can actually serve the chosen pathway, so the
  // shortlist always answers "who can do *this*", not "who exists".
  const partners = useMemo(
    () => data.partners.filter((entry) => entry.pathwayId === pathwayId),
    [data.partners, pathwayId],
  );

  // Resolved against the *filtered* list, so a partner selected on a previous
  // pathway simply stops resolving when the pathway changes. No reset needed -
  // the selection cannot outlive the pathway it belongs to.
  const partner = partners.find((entry) => entry.id === partnerId) ?? null;

  const urgent = data.minutesRemaining <= 15;

  // The module's rule, applied to the design's card order: a pathway below the
  // recommended one gives up a rung of the hierarchy.
  const dropsRung =
    recommended !== undefined &&
    pathway.id !== recommended.id &&
    pathway.tier !== recommended.tier;

  function report(message: string) {
    setNotice(message);
  }

  return (
    <ConsoleLayout
      title="Fallback Opportunity"
      subtitle={`${data.id} - ${data.minutesRemaining} min remaining`}
      statusStrip={
        <ConsoleStatusStrip
          activeRescues={status.activeRescues}
          needIntervention={1}
          version={status.consoleVersion}
        />
      }
    >
      <nav className="crumbs t-body-sm" aria-label="Breadcrumb">
        <Link className="linkbtn t-body-sm" to="/zero-waste">
          Fallback Opportunities
        </Link>
        <span aria-hidden="true">&rsaquo;</span>
        <span className="muted">New Recovery Opportunity</span>
      </nav>

      {id && id !== data.id && (
        <div className="alertcard alertcard--neutral" style={{ margin: 0 }}>
          <span className="t-body-sm">
            The fixtures hold a single fallback case, so <code>{id}</code>{' '}
            renders {data.id}. Phase 14 fetches the real case.
          </span>
        </div>
      )}

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">Alternative Recovery Required</h1>
          <p className="t-body-md">
            Find an approved recovery pathway for surplus food that could not be
            completed through the normal rescue network.
          </p>
        </div>
        <div className="intro__actions">
          <span className="pill t-label-sm">
            <span
              className="dot dot--pulse"
              style={{ background: 'var(--success)' }}
            />
            Network Live
          </span>
          <span className="t-label-sm muted">Updated just now</span>
        </div>
      </section>

      {/* The surplus banner. */}
      <section className="surplusbanner">
        <div className="surplusbanner__body">
          <div className="surplusbanner__tags">
            <span className="surplusbanner__tag surplusbanner__tag--alert t-label-sm">
              <span className="icon" style={{ fontSize: 13 }} aria-hidden="true">
                error
              </span>
              {data.tags[0]}
            </span>
            <span className="surplusbanner__tag t-label-sm">
              Original: {data.originRescueId}
            </span>
            <span className="surplusbanner__tag t-label-sm">
              {data.tags[1]}
            </span>
          </div>

          <h2 className="t-headline-lg surplusbanner__title">{data.partner}</h2>

          <p className="t-body-md surplusbanner__meta">
            Surplus: {data.surplusSummary} &middot; Current issue: {data.issue}
          </p>
        </div>

        <div
          className={`surplusbanner__timer${
            urgent ? ' surplusbanner__timer--urgent' : ''
          }`}
        >
          <span
            className="icon"
            style={{
              fontSize: 20,
              color: urgent ? '#ffdad6' : 'var(--primary-fixed)',
            }}
            aria-hidden="true"
          >
            timer
          </span>
          <span
            className="t-label-sm upper"
            style={{ color: 'var(--primary-fixed-dim)' }}
          >
            Time Remaining
          </span>
          <span
            className="t-metric"
            style={{
              fontSize: 28,
              lineHeight: '34px',
              fontWeight: 700,
              color: urgent ? '#ffdad6' : 'var(--on-primary)',
            }}
          >
            {data.minutesRemaining} min
          </span>
        </div>
      </section>

      <section className="sectorsplit">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          {/* Surplus inventory profile. */}
          <div className="card">
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                  <span
                    className="icon"
                    style={{ fontSize: 17, verticalAlign: '-3px', marginRight: 6 }}
                    aria-hidden="true"
                  >
                    inventory_2
                  </span>
                  Recovery Opportunity
                </h2>
                <span className="t-body-sm muted">
                  Surplus Inventory Profile
                </span>
              </div>
              <span
                className="chip t-label-sm"
                style={{
                  background: 'var(--primary-fixed)',
                  color: 'var(--on-primary-fixed)',
                }}
              >
                {data.inventory.state}
              </span>
            </div>

            <div className="statgrid">
              <div className="statgrid__cell">
                <span className="t-label-sm upper muted">Food &amp; Category</span>
                <span className="t-body-md" style={{ fontWeight: 600 }}>
                  {data.inventory.category}
                </span>
                <span className="t-body-sm muted">
                  {data.inventory.categoryDetail}
                </span>
              </div>
              <div className="statgrid__cell">
                <span className="t-label-sm upper muted">Available Window</span>
                <span className="t-body-md" style={{ fontWeight: 600 }}>
                  {data.inventory.window}
                </span>
                <span className="t-body-sm muted">
                  {data.inventory.windowDetail}
                </span>
              </div>
            </div>

            <div className="alertcard alertcard--info">
              <span className="icon" style={{ fontSize: 17 }} aria-hidden="true">
                info
              </span>
              <span className="t-body-sm">
                Food handling note: &ldquo;{data.inventory.handlingNote}&rdquo;
              </span>
            </div>
          </div>

          {/* Recovery pathways. */}
          <div className="card">
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                  <span
                    className="icon"
                    style={{ fontSize: 17, verticalAlign: '-3px', marginRight: 6 }}
                    aria-hidden="true"
                  >
                    alt_route
                  </span>
                  Available Recovery Pathways
                </h2>
                <span className="t-body-sm muted">
                  Select target diversion stream
                </span>
              </div>
            </div>

            <ul className="pathways">
              {data.pathways.map((entry) => {
                const on = entry.id === pathwayId;
                return (
                  <li key={entry.id}>
                    <button
                      type="button"
                      aria-pressed={on}
                      className={`pathway${on ? ' pathway--on' : ''}${
                        !on && entry.id === data.recommendedPathwayId
                          ? ' pathway--recommended'
                          : ''
                      }`}
                      onClick={() => setPathwayId(entry.id)}
                    >
                      <div className="pathway__head">
                        <span className="pathway__icon">
                          <span className="icon" style={{ fontSize: 19 }} aria-hidden="true">
                            {entry.icon}
                          </span>
                        </span>
                        <span
                          className="chip t-label-sm"
                          style={{
                            background: STATE_STYLE[entry.state].bg,
                            color: STATE_STYLE[entry.state].fg,
                          }}
                        >
                          {entry.statusLabel}
                        </span>
                      </div>

                      <span className="t-body-md" style={{ fontWeight: 600 }}>
                        {entry.name}
                      </span>
                      <span className="t-body-sm muted">{entry.detail}</span>
                      <TierChip tier={entry.tier} short />
                    </button>
                  </li>
                );
              })}
            </ul>
          </div>

          {/* Recommendation analysis. */}
          <div className="card">
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                  <span
                    className="icon"
                    style={{ fontSize: 17, verticalAlign: '-3px', marginRight: 6 }}
                    aria-hidden="true"
                  >
                    recommend
                  </span>
                  {pathway.id === data.recommendedPathwayId
                    ? `Recommended Pathway: ${pathway.name}`
                    : `Selected Pathway: ${pathway.name}`}
                </h2>
                <span className="t-body-sm muted">Optimal Match Analysis</span>
              </div>
              <span
                className="chip t-label-sm"
                style={{
                  background: STATE_STYLE[pathway.state].bg,
                  color: STATE_STYLE[pathway.state].fg,
                }}
              >
                Status: {pathway.statusLabel}
              </span>
            </div>

            <div
              className={`alertcard ${
                pathway.id === data.recommendedPathwayId
                  ? 'alertcard--good'
                  : 'alertcard--info'
              }`}
            >
              <span className="t-body-sm">
                {pathway.id === data.recommendedPathwayId
                  ? data.recommendationAnalysis
                  : `${pathway.detail}. ${
                      partners.length === 0
                        ? 'No partner on this pathway can be reached from the shortlist.'
                        : `${partners.length} partner${
                            partners.length === 1 ? '' : 's'
                          } available on this pathway.`
                    }`}
              </span>
            </div>

            {dropsRung && recommended && (
              <div className="alertcard alertcard--error" role="alert">
                <span className="t-body-sm">
                  <strong>This gives up a rung.</strong> {recommended.name} is
                  the higher recovery tier and is still available. Phase 14 must
                  require a recorded reason before accepting a lower pathway, so
                  the audit trail shows why the better one was passed over.
                </span>
              </div>
            )}

            <div className="controls" style={{ paddingTop: 0 }}>
              <button
                className="btn btn--primary"
                type="button"
                onClick={() => setShowPartners(true)}
                disabled={partners.length === 0}
              >
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  group
                </span>
                View available partners
              </button>
              <button
                className="btn btn--quiet"
                type="button"
                onClick={() => setPathwayId(data.recommendedPathwayId)}
                disabled={pathway.id === data.recommendedPathwayId}
              >
                Back to recommended pathway
              </button>
            </div>
          </div>

          {/* Partner shortlist. */}
          {showPartners && (
            <div className="card">
              <div className="section-head">
                <div style={{ minWidth: 0 }}>
                  <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                    <span
                      className="icon"
                      style={{ fontSize: 17, verticalAlign: '-3px', marginRight: 6 }}
                      aria-hidden="true"
                    >
                      local_shipping
                    </span>
                    Available Partners
                  </h2>
                  <span className="t-body-sm muted">
                    Filtered by proximity and capacity
                  </span>
                </div>
                <span className="t-label-sm muted">
                  {partners.length} on {pathway.name}
                </span>
              </div>

              <ul className="partnerpick">
                {partners.length === 0 && (
                  <li className="t-body-sm muted" style={{ padding: '4px 0' }}>
                    No partner on this pathway is reachable inside the window.
                  </li>
                )}

                {partners.map((entry) => {
                  const on = entry.id === partnerId;
                  const tooLate = entry.etaMinutes > data.minutesRemaining;
                  return (
                    <li
                      className={`partnerpick__row${
                        on ? ' partnerpick__row--on' : ''
                      }`}
                      key={entry.id}
                    >
                      <span className="partnerpick__mark t-label-md" aria-hidden="true">
                        {entry.mark}
                      </span>

                      <span className="partnerpick__body">
                        <span
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 8,
                            flexWrap: 'wrap',
                          }}
                        >
                          <span className="t-body-md" style={{ fontWeight: 600 }}>
                            {entry.name}
                          </span>
                          <span className="chip t-label-sm">{entry.kind}</span>
                          {tooLate && (
                            <span
                              className="chip t-label-sm"
                              style={{
                                background: 'var(--error-container)',
                                color: 'var(--on-error-container)',
                              }}
                            >
                              Arrives after window
                            </span>
                          )}
                        </span>
                        <span className="dtable__sub t-body-sm muted">
                          {entry.available ? 'Available' : 'Unavailable'} &middot;
                          Approx. {entry.etaMinutes} min away
                        </span>
                      </span>

                      <button
                        className={`btn ${on ? 'btn--primary' : 'btn--quiet'}`}
                        type="button"
                        onClick={() => setPartnerId(entry.id)}
                      >
                        {on ? 'Selected' : 'Select Partner'}
                      </button>
                    </li>
                  );
                })}
              </ul>
            </div>
          )}

          {/* Chain of custody. */}
          {partner && (
            <div className="card">
              <div className="section-head">
                <div style={{ minWidth: 0 }}>
                  <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                    <span
                      className="icon"
                      style={{ fontSize: 17, verticalAlign: '-3px', marginRight: 6 }}
                      aria-hidden="true"
                    >
                      route
                    </span>
                    Recovery Routing
                  </h2>
                  <span className="t-body-sm muted">
                    Chain of custody execution flow
                  </span>
                </div>
              </div>

              <div className="custody">
                <div className="custody__node">
                  <span className="t-label-sm upper muted">Origin</span>
                  <span className="t-body-md" style={{ fontWeight: 600 }}>
                    {data.routing.originName}
                  </span>
                  <span className="t-body-sm muted">
                    {data.routing.originDetail}
                  </span>
                </div>

                <span className="custody__arrow" aria-hidden="true">
                  <span className="icon" style={{ fontSize: 20 }}>
                    arrow_forward
                  </span>
                </span>

                <div className="custody__node custody__node--action">
                  <span className="t-label-sm upper muted">Routing Action</span>
                  <span className="t-body-md" style={{ fontWeight: 600 }}>
                    {data.routing.action}
                  </span>
                </div>

                <span className="custody__arrow" aria-hidden="true">
                  <span className="icon" style={{ fontSize: 20 }}>
                    arrow_forward
                  </span>
                </span>

                <div className="custody__node">
                  <span className="t-label-sm upper muted">Destination</span>
                  <span className="t-body-md" style={{ fontWeight: 600 }}>
                    {partner.name}
                  </span>
                  <span className="t-body-sm muted">
                    {partner.destinationKind}
                  </span>
                </div>
              </div>

              <div className="statgrid">
                <Fact label="Pickup Window" value={data.routing.pickupWindow} />
                <Fact label="Partner Status" value={data.routing.partnerStatus} />
                <Fact
                  label="Estimated Travel"
                  value={`${partner.etaMinutes} minutes`}
                />
                <Fact
                  label="Handover Req."
                  value={data.routing.handoverRequirement}
                />
              </div>

              <div className="controls" style={{ paddingTop: 0 }}>
                <button
                  className="btn btn--primary"
                  type="button"
                  onClick={() =>
                    report(
                      `Nothing was dispatched. Creating the handoff would send a collection request for ${data.surplusSummary} to ${partner.name} and issue the ${data.routing.handoverRequirement.toLowerCase()} code, which needs the Phase 14 dispatch service.`,
                    )
                  }
                >
                  <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                    done_all
                  </span>
                  Create recovery handoff
                </button>
                <button
                  className="btn btn--quiet"
                  type="button"
                  onClick={() => setPartnerId(null)}
                >
                  Choose another partner
                </button>
              </div>
            </div>
          )}

          {notice && (
            <div className="alertcard alertcard--info" role="status" style={{ margin: 0 }}>
              <span className="t-body-sm">
                <strong>Nothing was dispatched.</strong>{' '}
                {notice.replace('Nothing was dispatched. ', '')}
              </span>
            </div>
          )}
        </div>

        {/* Decision panel, activity trail, linked context. */}
        <aside style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          <div className="card">
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <span className="t-label-sm upper muted">Decision Panel</span>
                <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                  Operator Action
                </h2>
              </div>
            </div>

            <dl className="factlist">
              <div className="factlist__row">
                <dt className="t-body-sm muted">Current Recommendation</dt>
                <dd className="t-body-md" style={{ fontWeight: 600 }}>
                  {recommended?.name ?? '-'}
                </dd>
              </div>
              <div className="factlist__row">
                <dt className="t-body-sm muted">Selected Partner</dt>
                <dd className="t-body-md">{partner?.name ?? 'None yet'}</dd>
              </div>
            </dl>

            <div className="controls" style={{ paddingTop: 0 }}>
              <button
                className="btn btn--primary btn--block"
                type="button"
                disabled={!partner}
                title={partner ? undefined : 'Select a partner first'}
                onClick={() =>
                  partner &&
                  report(
                    `Creating the handoff would commit ${data.surplusSummary} to ${partner.name}, which needs the Phase 14 dispatch service.`,
                  )
                }
              >
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  check_circle
                </span>
                Create recovery handoff
              </button>

              <button
                className="btn btn--quiet btn--block"
                type="button"
                onClick={() => {
                  setShowPartners(false);
                  setPartnerId(null);
                }}
              >
                Choose another pathway
              </button>

              <button
                className="btn btn--quiet btn--block"
                type="button"
                onClick={() =>
                  report(
                    'Resuming the rescue search would re-enter this surplus into the human tier and ping rescuers again, which needs the Phase 14 dispatch service.',
                  )
                }
              >
                Continue rescue search
              </button>

              <button
                className="btn btn--danger btn--block"
                type="button"
                onClick={() => setConfirmCancel(true)}
              >
                Cancel recovery opportunity
              </button>
            </div>
          </div>

          <div className="card">
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <span className="t-label-sm upper muted">Audit Trail</span>
                <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                  Fallback Activity
                </h2>
              </div>
            </div>

            <ol className="audit">
              {data.activity.map((entry) => (
                <li className="audit__row" key={`${entry.time}-${entry.title}`}>
                  <span className="audit__rail" aria-hidden="true">
                    <span
                      className="audit__dot"
                      style={{
                        background: entry.done
                          ? 'var(--success)'
                          : 'var(--outline-variant)',
                      }}
                    />
                  </span>
                  <div className="audit__body">
                    <div className="audit__title">
                      <span className="t-body-md" style={{ fontWeight: 600 }}>
                        {entry.title}
                      </span>
                      <span className="t-label-sm muted">{entry.time}</span>
                    </div>
                  </div>
                </li>
              ))}
            </ol>
          </div>

          <div className="card">
            <div className="section-head">
              <div style={{ minWidth: 0 }}>
                <span className="t-label-sm upper muted">Linked Context</span>
                <h2 className="t-headline-sm" style={{ margin: 0, fontSize: 15 }}>
                  Origin rescue: {data.originRescueId}
                </h2>
              </div>
            </div>
            <div className="controls" style={{ paddingTop: 0 }}>
              <button
                className="btn btn--quiet btn--block"
                type="button"
                onClick={() => navigate(`/live-rescues/${data.originRescueId}`)}
              >
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  open_in_new
                </span>
                Open Rescue Operations
              </button>
              <Link className="btn btn--quiet btn--block" to="/activity">
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  history
                </span>
                Open the Activity Log
              </Link>
            </div>
          </div>
        </aside>
      </section>

      {/* The design's cancellation dialog. */}
      {confirmCancel && (
        <CancelDialog
          partner={data.partner}
          rescueId={data.originRescueId}
          onKeep={() => setConfirmCancel(false)}
          onConfirm={() => {
            setConfirmCancel(false);
            report(
              'Nothing was cancelled. Aborting the fallback routing would strand real surplus, so it needs the Phase 14 console API and the administrative confirmation the design calls for.',
            );
          }}
        />
      )}
    </ConsoleLayout>
  );
}

/**
 * "Cancel Recovery Opportunity?" - the design's confirmation dialog.
 *
 * Escape closes it, and the safe choice is the one that keeps focus, because
 * the destructive option here strands real food.
 */
function CancelDialog({
  partner,
  rescueId,
  onKeep,
  onConfirm,
}: {
  partner: string;
  rescueId: string;
  onKeep: () => void;
  onConfirm: () => void;
}) {
  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key === 'Escape') onKeep();
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onKeep]);

  return (
    <div
      className="modalscrim"
      role="presentation"
      onClick={(event) => {
        if (event.target === event.currentTarget) onKeep();
      }}
    >
      <div
        className="modal"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="cancel-title"
      >
        <span className="modal__mark" aria-hidden="true">
          <span className="icon" style={{ fontSize: 22 }}>
            warning
          </span>
        </span>

        <h2 className="t-headline-sm" id="cancel-title" style={{ margin: 0 }}>
          Cancel Recovery Opportunity?
        </h2>

        <p className="t-body-sm" style={{ margin: 0 }}>
          This action will abort the fallback routing for {partner} ({rescueId}).
          This requires administrative confirmation.
        </p>

        <div className="modal__actions">
          <button className="btn btn--quiet" type="button" onClick={onKeep} autoFocus>
            Keep Active
          </button>
          <button className="btn btn--danger" type="button" onClick={onConfirm}>
            Confirm Cancellation
          </button>
        </div>
      </div>
    </div>
  );
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div className="statgrid__cell">
      <span className="t-label-sm upper muted">{label}</span>
      <span className="t-body-md" style={{ fontWeight: 600 }}>
        {value}
      </span>
    </div>
  );
}
