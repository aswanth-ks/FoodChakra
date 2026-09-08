import { useState } from 'react';
import type {
  CoverageData,
  ResponderMode,
} from '../data/coverageTypes';

const MODE_ICON: Record<ResponderMode, string> = {
  van: 'local_shipping',
  bike: 'pedal_bike',
  foot: 'directions_walk',
};

const RING_COLOR = {
  standard: 'var(--map-route-green)',
  expanded: 'var(--warning)',
  extended: 'var(--error)',
  alternative: 'var(--primary)',
} as const;

const ZOOM_STEPS = [1, 1.25, 1.5, 1.8] as const;

/**
 * The coverage map: concentric rings showing how far the search has widened,
 * the rescue at the centre, and the responders inside each band.
 *
 * Drawn, not cartographic — Phase 14 replaces it with a real map surface.
 */
export default function CoverageMap({ data }: { data: CoverageData }) {
  const [zoomIndex, setZoomIndex] = useState(0);
  const zoom = ZOOM_STEPS[zoomIndex] ?? 1;

  const focus = data.sites.find((site) => site.focus);

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
          className="opsmap__zoombtn"
          type="button"
          aria-label="Fit to screen"
          onClick={() => setZoomIndex(0)}
        >
          <span className="icon" style={{ fontSize: 18 }}>
            fit_screen
          </span>
        </button>
      </div>

      <svg
        viewBox="0 0 880 500"
        xmlns="http://www.w3.org/2000/svg"
        role="img"
        aria-label={`Coverage map centred on ${focus?.label ?? 'the rescue'}, showing ${data.responders.length} nearby responders across ${data.rings.length} coverage bands`}
        style={{ transform: `scale(${zoom})` }}
      >
        <defs>
          <pattern id="cov-grid" width="44" height="44" patternUnits="userSpaceOnUse">
            <path
              d="M 44 0 L 0 0 0 44"
              fill="none"
              stroke="var(--map-grid)"
              strokeWidth="0.8"
              opacity="0.75"
            />
          </pattern>
        </defs>

        <rect width="100%" height="100%" fill="var(--map-base)" />
        <rect width="100%" height="100%" fill="url(#cov-grid)" />

        <path
          d="M -10,340 C 190,330 300,270 460,290 C 620,310 730,240 890,255 L 890,320 C 720,300 590,385 430,355 C 250,325 120,400 -10,400 Z"
          fill="var(--map-water)"
          opacity="0.55"
        />

        <g stroke="var(--map-road)" strokeWidth="8" strokeLinecap="round" fill="none">
          <path d="M 30,80 Q 250,150 480,130 T 860,110" />
          <path d="M 110,470 L 320,310 L 540,200 L 820,210" />
          <path d="M 430,30 L 430,470" />
          <path d="M 700,50 L 700,460" />
          <path d="M 175,80 L 175,450" />
        </g>
        <g stroke="var(--map-lane)" strokeWidth="3" strokeLinecap="round" fill="none">
          <path d="M 30,80 Q 250,150 480,130 T 860,110" />
          <path d="M 110,470 L 320,310 L 540,200 L 820,210" />
          <path d="M 430,30 L 430,470" />
          <path d="M 700,50 L 700,460" />
          <path d="M 175,80 L 175,450" />
        </g>

        {/* Coverage bands, widest first so the tightest sits on top. */}
        {focus &&
          [...data.rings].reverse().map((ring) => (
            <g key={ring.level}>
              <circle
                cx={focus.x}
                cy={focus.y}
                r={ring.radius}
                fill={RING_COLOR[ring.level]}
                opacity="0.06"
              />
              <circle
                cx={focus.x}
                cy={focus.y}
                r={ring.radius}
                fill="none"
                stroke={RING_COLOR[ring.level]}
                strokeWidth="1.5"
                strokeDasharray={ring.level === 'standard' ? undefined : '6,5'}
                opacity="0.85"
              />
            </g>
          ))}

        {data.sites
          .filter((site) => !site.focus)
          .map((site) => (
            <g key={site.id}>
              <title>{site.label}</title>
              <circle
                cx={site.x}
                cy={site.y}
                r="6"
                fill="var(--map-node-idle)"
                stroke="var(--map-lane)"
                strokeWidth="2"
              />
              <text
                x={site.x}
                y={site.y + 20}
                textAnchor="middle"
                fontFamily="Inter"
                fontSize="10"
                fontWeight="600"
                fill="var(--map-watermark)"
              >
                {site.label}
              </text>
            </g>
          ))}

        {data.responders.map((responder) => (
          <g key={responder.id}>
            <title>{responder.caption}</title>
            <circle
              cx={responder.x}
              cy={responder.y}
              r="15"
              fill="var(--surface-container-lowest)"
              stroke="var(--primary)"
              strokeWidth="2"
            />
            <text
              x={responder.x}
              y={responder.y + 5}
              textAnchor="middle"
              fontFamily="Material Symbols Outlined"
              fontSize="15"
              fill="var(--primary)"
            >
              {MODE_ICON[responder.mode]}
            </text>
            <text
              x={responder.x}
              y={responder.y + 30}
              textAnchor="middle"
              fontFamily="Inter"
              fontSize="9.5"
              fontWeight="600"
              fill="var(--on-surface-variant)"
            >
              {responder.label}
            </text>
          </g>
        ))}

        {focus && (
          <g>
            <title>
              {focus.label} {focus.detail}
            </title>
            <circle cx={focus.x} cy={focus.y} r="22" fill="var(--error)" opacity="0.2">
              <animate
                attributeName="r"
                values="18;34;18"
                dur="2.2s"
                repeatCount="indefinite"
              />
              <animate
                attributeName="opacity"
                values="0.28;0;0.28"
                dur="2.2s"
                repeatCount="indefinite"
              />
            </circle>
            <circle
              cx={focus.x}
              cy={focus.y}
              r="17"
              fill="var(--error)"
              stroke="var(--map-lane)"
              strokeWidth="3"
            />
            <text
              x={focus.x}
              y={focus.y + 6}
              textAnchor="middle"
              fontFamily="Material Symbols Outlined"
              fontSize="17"
              fill="#ffffff"
            >
              restaurant
            </text>
            <text
              x={focus.x}
              y={focus.y + 36}
              textAnchor="middle"
              fontFamily="Inter"
              fontSize="11"
              fontWeight="700"
              fill="var(--on-surface)"
            >
              {focus.label}
            </text>
            <text
              x={focus.x}
              y={focus.y + 49}
              textAnchor="middle"
              fontFamily="Inter"
              fontSize="10"
              fontWeight="600"
              fill="var(--error)"
            >
              {focus.detail}
            </text>
          </g>
        )}
      </svg>

      {focus && (
        <div className="coverage__focusbadge">
          <span className="t-label-sm upper" style={{ opacity: 0.8 }}>
            Focus Rescue
          </span>
          <span className="t-body-sm" style={{ fontWeight: 600 }}>
            {focus.label} · {focus.detail?.replace(/[()]/g, '')}
          </span>
        </div>
      )}

      <div className="coverage__legend t-label-sm">
        <span>
          <span className="dot" style={{ background: RING_COLOR.standard }} />
          Normal coverage
        </span>
        <span>
          <span className="dot" style={{ background: RING_COLOR.expanded }} />
          Expanded coverage
        </span>
        <span>
          <span className="dot" style={{ background: RING_COLOR.extended }} />
          Extended coverage
        </span>
        <span>
          <span className="icon" style={{ fontSize: 13 }} aria-hidden="true">
            two_wheeler
          </span>
          Active rescuer ({data.responders.length} nearby)
        </span>
        <span style={{ color: 'var(--error)' }}>
          <span className="icon" style={{ fontSize: 13 }} aria-hidden="true">
            warning
          </span>
          Attention required
        </span>
      </div>
    </div>
  );
}
