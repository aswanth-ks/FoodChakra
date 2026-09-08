import type { Kpi, KpiTone } from '../data/overviewTypes';

/** Maps a card's tone to its number colour and status dot. */
const TONE_COLOR: Record<KpiTone, string> = {
  nominal: 'var(--primary)',
  neutral: 'var(--on-surface)',
  warning: 'var(--warning-deep)',
  critical: 'var(--error)',
};

const DOT_COLOR: Record<KpiTone, string> = {
  nominal: 'var(--success)',
  neutral: 'var(--secondary-fixed-dim)',
  warning: 'var(--warning)',
  critical: 'var(--error)',
};

const DOT_TITLE: Record<KpiTone, string> = {
  nominal: 'Nominal state',
  neutral: 'In dispatch cycle',
  warning: 'Window closing',
  critical: 'Needs intervention',
};

/** The four headline numbers across the top of the Overview. */
export default function KpiRow({ kpis }: { kpis: Kpi[] }) {
  return (
    <section className="kpis" aria-label="Network status at a glance">
      {kpis.map((kpi) => {
        const color = TONE_COLOR[kpi.tone];
        const critical = kpi.tone === 'critical';

        return (
          <article className="card kpi" key={kpi.label}>
            <div className="kpi__head">
              <span
                className="t-label-sm upper"
                style={{
                  color: critical ? 'var(--error)' : 'var(--on-surface-variant)',
                }}
              >
                {kpi.label}
              </span>
              <span
                className={`dot${critical ? ' dot--pulse' : ''}`}
                style={{ background: DOT_COLOR[kpi.tone] }}
                title={DOT_TITLE[kpi.tone]}
              />
            </div>

            <div className="kpi__value">
              <span
                className="t-metric"
                style={{ fontSize: 32, lineHeight: '40px', color, fontWeight: 700 }}
              >
                {kpi.value}
              </span>

              {kpi.noteAsBadge ? (
                <span
                  className="chip t-label-sm"
                  style={{
                    background: 'var(--error-container)',
                    color: 'var(--on-error-container)',
                  }}
                >
                  {kpi.note}
                </span>
              ) : (
                <span
                  className="kpi__trend t-label-sm"
                  style={{
                    color:
                      kpi.tone === 'nominal'
                        ? 'var(--success)'
                        : kpi.tone === 'warning'
                          ? 'var(--warning-deep)'
                          : 'var(--on-surface-variant)',
                  }}
                >
                  {kpi.noteIcon && (
                    <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
                      {kpi.noteIcon}
                    </span>
                  )}
                  {kpi.note}
                </span>
              )}
            </div>

            <div
              className="kpi__foot t-body-sm truncate"
              style={critical ? { color: 'var(--error)', fontWeight: 500 } : undefined}
            >
              {kpi.captionIcon && (
                <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                  {kpi.captionIcon}
                </span>
              )}
              <span className="truncate">{kpi.caption}</span>
            </div>
          </article>
        );
      })}
    </section>
  );
}
