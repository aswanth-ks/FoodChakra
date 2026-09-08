import { useState } from 'react';
import type { RescueSeverity, RescueSummary } from '../data/rescueTypes';
import { formatRemaining } from '../data/rescueTypes';
import { SEVERITY_COLOR, SEVERITY_LABEL } from '../data/severity';

const ZOOM_STEPS = [1, 1.3, 1.6, 2] as const;

/**
 * The console's large operational map.
 *
 * A drawn schematic rather than cartography, matching the design — Phase 14
 * replaces it with a real map surface. Markers carry their own labels for the
 * two cases that need attention, as in the design.
 */
export default function OperationsMap({
  rescues,
  selectedId,
  onSelect,
}: {
  rescues: RescueSummary[];
  selectedId: string | null;
  onSelect: (id: string) => void;
}) {
  const [zoomIndex, setZoomIndex] = useState(0);
  const zoom = ZOOM_STEPS[zoomIndex] ?? 1;

  return (
    <div className="opsmap__canvas">
      <div className="opsmap__zoom">
        <button
          className="opsmap__zoombtn"
          type="button"
          aria-label="Zoom in"
          onClick={() => setZoomIndex((i) => Math.min(i + 1, ZOOM_STEPS.length - 1))}
          disabled={zoomIndex === ZOOM_STEPS.length - 1}
        >
          <span className="icon" style={{ fontSize: 18 }}>
            add
          </span>
        </button>
        <button
          className="opsmap__zoombtn"
          type="button"
          aria-label="Zoom out"
          onClick={() => setZoomIndex((i) => Math.max(i - 1, 0))}
          disabled={zoomIndex === 0}
        >
          <span className="icon" style={{ fontSize: 18 }}>
            remove
          </span>
        </button>
        <button
          className="toolbtn t-label-md"
          type="button"
          onClick={() => setZoomIndex(0)}
        >
          <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
            my_location
          </span>
          Recenter
        </button>
      </div>

      <svg
        viewBox="0 0 900 560"
        xmlns="http://www.w3.org/2000/svg"
        role="img"
        aria-label={`Operational map showing ${rescues.length} rescues`}
        style={{ transform: `scale(${zoom})` }}
      >
        <defs>
          <pattern id="ops-grid" width="45" height="45" patternUnits="userSpaceOnUse">
            <path
              d="M 45 0 L 0 0 0 45"
              fill="none"
              stroke="var(--map-grid)"
              strokeWidth="0.8"
              opacity="0.8"
            />
          </pattern>
        </defs>

        <rect width="100%" height="100%" fill="var(--map-base)" />
        <rect width="100%" height="100%" fill="url(#ops-grid)" />

        <path
          d="M -10,380 C 200,370 320,300 480,320 C 640,340 760,260 920,280 L 920,350 C 740,330 600,420 440,390 C 260,360 130,440 -10,440 Z"
          fill="var(--map-water)"
          opacity="0.6"
        />

        <g stroke="var(--map-district)" strokeDasharray="5,5" strokeWidth="1">
          <path d="M 300,0 L 300,560" />
          <path d="M 620,0 L 620,560" />
          <path d="M 0,250 L 900,250" />
        </g>

        <g stroke="var(--map-road)" strokeWidth="9" strokeLinecap="round" fill="none">
          <path d="M 40,90 Q 260,160 500,140 T 870,120" />
          <path d="M 120,530 L 340,340 L 560,220 L 830,230" />
          <path d="M 470,40 L 470,520" />
          <path d="M 740,60 L 740,510" />
          <path d="M 190,90 L 190,500" />
        </g>
        <g stroke="var(--map-lane)" strokeWidth="3" strokeLinecap="round" fill="none">
          <path d="M 40,90 Q 260,160 500,140 T 870,120" />
          <path d="M 120,530 L 340,340 L 560,220 L 830,230" />
          <path d="M 470,40 L 470,520" />
          <path d="M 740,60 L 740,510" />
          <path d="M 190,90 L 190,500" />
        </g>

        {rescues.map((rescue) => {
          const color = SEVERITY_COLOR[rescue.severity];
          const selected = rescue.id === selectedId;
          const flagged =
            rescue.severity === 'critical' || rescue.severity === 'attention';

          return (
            <g
              key={rescue.id}
              className="opsmap__marker"
              onClick={() => onSelect(rescue.id)}
              role="button"
              tabIndex={0}
              aria-label={`${rescue.partner}, ${SEVERITY_LABEL[rescue.severity]}, ${formatRemaining(rescue.minutesRemaining)}`}
              onKeyDown={(event) => {
                if (event.key === 'Enter' || event.key === ' ') {
                  event.preventDefault();
                  onSelect(rescue.id);
                }
              }}
            >
              <title>
                {rescue.partner} · {SEVERITY_LABEL[rescue.severity]} ·{' '}
                {formatRemaining(rescue.minutesRemaining)}
              </title>

              {rescue.severity === 'critical' && (
                <circle cx={rescue.x} cy={rescue.y} r="16" fill={color} opacity="0.2">
                  <animate
                    attributeName="r"
                    values="12;26;12"
                    dur="2s"
                    repeatCount="indefinite"
                  />
                  <animate
                    attributeName="opacity"
                    values="0.3;0;0.3"
                    dur="2s"
                    repeatCount="indefinite"
                  />
                </circle>
              )}

              {selected && (
                <circle
                  cx={rescue.x}
                  cy={rescue.y}
                  r="20"
                  fill="none"
                  stroke={color}
                  strokeWidth="2"
                  strokeDasharray="3,3"
                />
              )}

              <circle
                cx={rescue.x}
                cy={rescue.y}
                r="13"
                fill={color}
                stroke="var(--map-lane)"
                strokeWidth="2.5"
              />

              {/* The design labels the two flagged markers inline so an
                  operator can read the board without hovering. */}
              {flagged && (
                <g>
                  <rect
                    x={rescue.x - 78}
                    y={rescue.y + 20}
                    width="156"
                    height="34"
                    rx="8"
                    fill="var(--surface-container-lowest)"
                    stroke={color}
                  />
                  <text
                    x={rescue.x}
                    y={rescue.y + 34}
                    textAnchor="middle"
                    fontFamily="Inter"
                    fontSize="11"
                    fontWeight="700"
                    fill="var(--on-surface)"
                  >
                    {rescue.partner}
                  </text>
                  <text
                    x={rescue.x}
                    y={rescue.y + 47}
                    textAnchor="middle"
                    fontFamily="Inter"
                    fontSize="10"
                    fontWeight="600"
                    fill={color}
                  >
                    {SEVERITY_LABEL[rescue.severity]} ·{' '}
                    {formatRemaining(rescue.minutesRemaining)}
                  </text>
                </g>
              )}
            </g>
          );
        })}
      </svg>

      <div className="opsmap__legend t-label-sm">
        {(['active', 'attention', 'critical', 'completed'] as RescueSeverity[]).map(
          (severity) => (
            <div key={severity}>
              <span className="dot" style={{ background: SEVERITY_COLOR[severity] }} />
              {SEVERITY_LABEL[severity]}
            </div>
          ),
        )}
      </div>

      <div className="opsmap__badge t-label-sm">
        <span className="icon" style={{ fontSize: 14 }} aria-hidden="true">
          hub
        </span>
        Live network
      </div>
    </div>
  );
}
