import type { HealthMetric } from '../data/overviewTypes';

/** Turns 0-1 samples into an SVG polyline across a 100x28 box. */
function sparkPoints(trend: number[]): string {
  if (trend.length < 2) return '';
  const step = 100 / (trend.length - 1);
  return trend
    .map((value, index) => {
      const x = index * step;
      // 3px of padding top and bottom so the stroke is never clipped.
      const y = 25 - value * 22;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(' ');
}

/** Trailing 24-hour baselines for the network. */
export default function NetworkHealth({ metrics }: { metrics: HealthMetric[] }) {
  return (
    <section className="card" aria-label="Network health">
      <div className="section-head">
        <h2 className="t-headline-sm" style={{ margin: 0 }}>
          Network health
        </h2>
        <span className="t-label-sm muted">Trailing 24-hour baseline</span>
      </div>

      <div className="health__grid">
        {metrics.map((metric) => (
          <article className="health__tile" key={metric.label}>
            <div className="health__head">
              <span className="t-label-sm upper">{metric.label}</span>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                {metric.icon}
              </span>
            </div>

            <div className="health__value">
              <span
                className="t-metric"
                style={{ fontSize: 22, lineHeight: '28px', color: 'var(--primary)' }}
              >
                {metric.value}
              </span>
              <span
                className="t-label-sm"
                style={{
                  color: metric.positive
                    ? 'var(--success)'
                    : 'var(--on-surface-variant)',
                }}
              >
                {metric.note}
              </span>
            </div>

            <svg
              className="spark"
              viewBox="0 0 100 28"
              preserveAspectRatio="none"
              role="img"
              aria-label={`${metric.label} trend over the last 24 hours`}
            >
              <polyline
                points={sparkPoints(metric.trend)}
                fill="none"
                stroke={metric.positive ? 'var(--success)' : 'var(--primary-fixed-dim)'}
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
                vectorEffect="non-scaling-stroke"
              />
            </svg>
          </article>
        ))}
      </div>
    </section>
  );
}
