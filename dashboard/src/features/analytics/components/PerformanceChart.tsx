import { useState } from 'react';
import type { DailyVolume } from '../data/analyticsTypes';

const WIDTH = 720;
const HEIGHT = 220;
const PAD_LEFT = 34;
const PAD_BOTTOM = 22;
const PAD_TOP = 10;

/**
 * Daily completed vs unresolved volume.
 *
 * Drawn as an SVG rather than pulling in a charting library: two series over
 * thirty points does not justify the dependency, and this keeps the chart on
 * the console's own tokens. Hovering a day reads out both figures.
 */
export default function PerformanceChart({
  daily,
  showCompleted,
  showUnresolved,
}: {
  daily: DailyVolume[];
  showCompleted: boolean;
  showUnresolved: boolean;
}) {
  const [hover, setHover] = useState<number | null>(null);

  const max = Math.max(
    ...daily.map((day) => Math.max(day.completed, day.unresolved)),
    1,
  );
  // Round the axis up to a clean figure so the gridlines read sensibly.
  const ceiling = Math.ceil(max / 10) * 10;

  const plotWidth = WIDTH - PAD_LEFT;
  const plotHeight = HEIGHT - PAD_BOTTOM - PAD_TOP;
  const stepX = plotWidth / Math.max(daily.length - 1, 1);

  const x = (index: number) => PAD_LEFT + index * stepX;
  const y = (value: number) =>
    PAD_TOP + plotHeight - (value / ceiling) * plotHeight;

  const line = (pick: (day: DailyVolume) => number) =>
    daily.map((day, index) => `${x(index)},${y(pick(day))}`).join(' ');

  const area = (pick: (day: DailyVolume) => number) =>
    `${PAD_LEFT},${PAD_TOP + plotHeight} ${line(pick)} ${x(daily.length - 1)},${
      PAD_TOP + plotHeight
    }`;

  const active = hover !== null ? daily[hover] : null;

  return (
    <div className="chart">
      <svg
        viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
        role="img"
        aria-label={`Daily rescue volume over ${daily.length} days. Completed peaks at ${Math.max(
          ...daily.map((d) => d.completed),
        )}, unresolved stays at or below ${Math.max(
          ...daily.map((d) => d.unresolved),
        )}.`}
        onMouseLeave={() => setHover(null)}
      >
        {/* Horizontal gridlines and their labels. */}
        {[0, 0.25, 0.5, 0.75, 1].map((fraction) => {
          const value = Math.round(ceiling * fraction);
          return (
            <g key={fraction}>
              <line
                x1={PAD_LEFT}
                x2={WIDTH}
                y1={y(value)}
                y2={y(value)}
                stroke="var(--outline-variant)"
                strokeWidth="1"
                opacity="0.45"
              />
              <text
                x={PAD_LEFT - 8}
                y={y(value) + 3.5}
                textAnchor="end"
                fontFamily="Inter"
                fontSize="9"
                fill="var(--on-surface-variant)"
              >
                {value}
              </text>
            </g>
          );
        })}

        {showCompleted && (
          <>
            <polygon
              points={area((day) => day.completed)}
              fill="var(--primary)"
              opacity="0.08"
            />
            <polyline
              points={line((day) => day.completed)}
              fill="none"
              stroke="var(--primary)"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </>
        )}

        {showUnresolved && (
          <polyline
            points={line((day) => day.unresolved)}
            fill="none"
            stroke="var(--error)"
            strokeWidth="2"
            strokeDasharray="4,4"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        )}

        {hover !== null && (
          <line
            x1={x(hover)}
            x2={x(hover)}
            y1={PAD_TOP}
            y2={PAD_TOP + plotHeight}
            stroke="var(--on-surface-variant)"
            strokeWidth="1"
            strokeDasharray="3,3"
          />
        )}

        {/* One hit target per day, so hovering is forgiving. */}
        {daily.map((_, index) => (
          <rect
            key={index}
            x={x(index) - stepX / 2}
            y={PAD_TOP}
            width={stepX}
            height={plotHeight}
            fill="transparent"
            onMouseEnter={() => setHover(index)}
          />
        ))}
      </svg>

      <div className="chart__axis t-label-sm muted">
        <span>Day 1 (00:00)</span>
        <span>Day 7</span>
        <span>Day 14</span>
        <span>Day 21</span>
        <span>Day 30 (Current)</span>
      </div>

      {active && (
        <div className="chart__readout t-label-sm" role="status">
          <span>Day {(hover ?? 0) + 1}</span>
          <span style={{ color: 'var(--primary)' }}>
            {active.completed} completed
          </span>
          <span style={{ color: 'var(--error)' }}>
            {active.unresolved} unresolved
          </span>
        </div>
      )}
    </div>
  );
}
