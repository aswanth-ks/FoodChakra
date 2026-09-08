import type { PriorityCase } from '../data/overviewTypes';

/**
 * Cases needing a human, most urgent first.
 *
 * This is the column an operator actually works from, so each row carries the
 * three things a decision needs: what it is, how long is left, and why it is
 * stuck.
 */
export default function PriorityQueue({
  cases,
  footnote,
  totalLiveQueue,
  onIntervene,
}: {
  cases: PriorityCase[];
  footnote: string;
  totalLiveQueue: number;
  onIntervene: (item: PriorityCase) => void;
}) {
  return (
    <section className="card queue" aria-label="Priority queue">
      <div className="section-head">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <h2 className="t-headline-sm" style={{ margin: 0 }}>
              Priority queue
            </h2>
            <span
              className="chip t-label-sm"
              style={{
                background: 'var(--error-container)',
                color: 'var(--on-error-container)',
              }}
            >
              {cases.length}
            </span>
          </div>
          <span className="t-body-sm muted">Cases requiring attention</span>
        </div>
        {/* Filtering needs the Phase 14 console API. */}
        <button className="iconbtn" type="button" disabled aria-label="Filter queue">
          <span className="icon" style={{ fontSize: 20 }}>
            filter_list
          </span>
        </button>
      </div>

      <div className="queue__list">
        {cases.map((item) => {
          const critical = item.severity === 'critical';
          const accent = critical ? 'var(--error)' : 'var(--warning-deep)';

          return (
            <article
              className={`qitem qitem--${item.severity}`}
              key={item.id}
            >
              <div className="qitem__head">
                <div style={{ minWidth: 0 }}>
                  <div className="t-body-md truncate" style={{ fontWeight: 600 }}>
                    {item.title}
                  </div>
                  <div className="t-body-sm muted truncate">{item.source}</div>
                </div>
                <span
                  className="chip t-label-sm"
                  style={{
                    background: critical
                      ? 'var(--error-container)'
                      : 'var(--warning-bg)',
                    color: critical ? 'var(--on-error-container)' : 'var(--warning-deep)',
                    border: `1px solid ${critical ? 'transparent' : 'var(--warning-border)'}`,
                    flexShrink: 0,
                  }}
                >
                  {critical ? 'CRITICAL' : 'ATTENTION'}
                </span>
              </div>

              <div className="qitem__meta t-body-sm">
                <span
                  className="icon"
                  style={{ fontSize: 15, color: accent }}
                  aria-hidden="true"
                >
                  {item.timerIcon}
                </span>
                <span className="t-metric" style={{ color: accent, fontSize: 13 }}>
                  {item.minutesRemaining} min remaining
                </span>
                <span aria-hidden="true">·</span>
                <span className="truncate">{item.status}</span>
              </div>

              <div className="qitem__foot">
                <span className="t-label-sm muted truncate">{item.detail}</span>
                <button
                  className={`btn ${critical ? 'btn--danger' : 'btn--quiet'}`}
                  type="button"
                  onClick={() => onIntervene(item)}
                >
                  {item.actionLabel}
                  <span className="icon" style={{ fontSize: 14 }} aria-hidden="true">
                    arrow_forward
                  </span>
                </button>
              </div>
            </article>
          );
        })}
      </div>

      <div className="queue__foot t-body-sm">
        <span className="truncate">{footnote}</span>
        {/* The full queue is its own console page, which is not built yet. */}
        <button type="button" disabled title="Rescue Queue — not built yet">
          View all live queue ({totalLiveQueue})
          <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
            chevron_right
          </span>
        </button>
      </div>
    </section>
  );
}
