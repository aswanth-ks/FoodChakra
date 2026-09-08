import { useState } from 'react';
import type { MapNode, MapNodeKind, MapRoute } from '../data/overviewTypes';

const NODE_FILL: Record<MapNodeKind, string> = {
  matched: 'var(--map-route-green)',
  attention: 'var(--map-route-amber)',
  critical: 'var(--error)',
  idle: 'var(--map-node-idle)',
};

const ZOOM_STEPS = [1, 1.25, 1.5, 1.85] as const;

/**
 * The live rescue network map.
 *
 * A drawn schematic, not cartography — the design is an abstract sector view
 * rather than a real basemap, and the same is true here. Phase 14 swaps this
 * for a real map surface fed by live coordinates; the node and route shapes
 * already carry everything that surface would need.
 */
export default function NetworkMap({
  nodes,
  routes,
  legend,
  broadcast,
}: {
  nodes: MapNode[];
  routes: MapRoute[];
  legend: { label: string; kind: MapNodeKind }[];
  broadcast: string;
}) {
  const [zoomIndex, setZoomIndex] = useState(0);
  const [showLayers, setShowLayers] = useState(true);

  const zoom = ZOOM_STEPS[zoomIndex] ?? 1;

  return (
    <section className="card map" aria-label="Live rescue network">
      <div className="section-head">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <h2 className="t-headline-sm" style={{ margin: 0 }}>
              Live rescue network
            </h2>
            <span
              className="chip t-label-sm"
              style={{
                background: 'var(--primary-fixed)',
                color: 'var(--on-primary-fixed)',
              }}
            >
              <span className="dot dot--pulse" style={{ background: 'var(--success)' }} />
              LIVE
            </span>
          </div>
          <span className="t-body-sm muted">
            Real-time view of active rescue opportunities and routing vectors.
          </span>
        </div>

        <div className="map__tools">
          <div className="map__zoom">
            <button
              type="button"
              title="Zoom in"
              aria-label="Zoom in"
              onClick={() =>
                setZoomIndex((i) => Math.min(i + 1, ZOOM_STEPS.length - 1))
              }
              disabled={zoomIndex === ZOOM_STEPS.length - 1}
            >
              <span className="icon" style={{ fontSize: 18 }}>
                add
              </span>
            </button>
            <span className="divider" />
            <button
              type="button"
              title="Zoom out"
              aria-label="Zoom out"
              onClick={() => setZoomIndex((i) => Math.max(i - 1, 0))}
              disabled={zoomIndex === 0}
            >
              <span className="icon" style={{ fontSize: 18 }}>
                remove
              </span>
            </button>
          </div>

          <button
            className="toolbtn t-label-md"
            type="button"
            onClick={() => setZoomIndex(0)}
          >
            <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
              crop_free
            </span>
            Reset
          </button>

          <button
            className="toolbtn t-label-md"
            type="button"
            aria-pressed={showLayers}
            onClick={() => setShowLayers((value) => !value)}
          >
            <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
              layers
            </span>
            Layers
          </button>
        </div>
      </div>

      <div className="map__canvas">
        <svg
          viewBox="0 0 880 480"
          xmlns="http://www.w3.org/2000/svg"
          role="img"
          aria-label={`Sector map showing ${nodes.length} network nodes and ${routes.length} active routes`}
          style={{ transform: `scale(${zoom})` }}
        >
          <defs>
            <pattern id="grid-pattern" width="40" height="40" patternUnits="userSpaceOnUse">
              <path
                d="M 40 0 L 0 0 0 40"
                fill="none"
                stroke="var(--map-grid)"
                strokeWidth="0.8"
                opacity="0.75"
              />
            </pattern>
            <marker
              id="arrow-green"
              viewBox="0 0 10 10"
              refX="5"
              refY="5"
              markerWidth="4"
              markerHeight="4"
              orient="auto-start-reverse"
            >
              <path d="M 0 1.5 L 8 5 L 0 8.5 z" fill="var(--map-route-green)" />
            </marker>
            <marker
              id="arrow-amber"
              viewBox="0 0 10 10"
              refX="5"
              refY="5"
              markerWidth="4"
              markerHeight="4"
              orient="auto-start-reverse"
            >
              <path d="M 0 1.5 L 8 5 L 0 8.5 z" fill="var(--map-route-amber)" />
            </marker>
          </defs>

          <rect width="100%" height="100%" fill="var(--map-base)" />
          <rect width="100%" height="100%" fill="url(#grid-pattern)" />

          {/* Water body, as a geographic anchor. */}
          <path
            d="M -10,320 C 180,310 260,250 420,270 C 580,290 690,210 900,230 L 900,290 C 720,270 590,360 410,330 C 230,300 120,380 -10,380 Z"
            fill="var(--map-water)"
            opacity="0.65"
          />

          {showLayers && (
            <g>
              {/* District boundaries and their labels. */}
              <path d="M 210,0 L 210,480" stroke="var(--map-district)" strokeDasharray="4,4" strokeWidth="1" />
              <path d="M 590,0 L 590,480" stroke="var(--map-district)" strokeDasharray="4,4" strokeWidth="1" />
              <path d="M 0,160 L 880,160" stroke="var(--map-district)" strokeDasharray="4,4" strokeWidth="1" />
              <text x="35" y="35" fill="var(--map-watermark)" fontFamily="Inter" fontSize="11" fontWeight="600" letterSpacing="0.1em">
                SECTOR 01 // INDUSTRIAL NORTH
              </text>
              <text x="240" y="35" fill="var(--map-watermark)" fontFamily="Inter" fontSize="11" fontWeight="600" letterSpacing="0.1em">
                SECTOR 02 // METRO CENTRAL
              </text>
              <text x="620" y="35" fill="var(--map-watermark)" fontFamily="Inter" fontSize="11" fontWeight="600" letterSpacing="0.1em">
                SECTOR 03 // EAST HARBOR
              </text>
            </g>
          )}

          {/* Arterial corridors, drawn twice for the road/lane effect. */}
          <g stroke="var(--map-road)" strokeWidth="8" strokeLinecap="round" strokeLinejoin="round" fill="none">
            <path d="M 60,40 Q 230,120 450,110 T 820,90" />
            <path d="M 120,440 L 320,290 L 510,180 L 760,190" />
            <path d="M 450,40 L 450,440" />
            <path d="M 720,50 L 720,430" />
            <path d="M 160,80 L 160,420" />
          </g>
          <g stroke="var(--map-lane)" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" fill="none">
            <path d="M 60,40 Q 230,120 450,110 T 820,90" />
            <path d="M 120,440 L 320,290 L 510,180 L 760,190" />
            <path d="M 450,40 L 450,440" />
            <path d="M 720,50 L 720,430" />
            <path d="M 160,80 L 160,420" />
          </g>

          {routes.map((route) => (
            <path
              key={route.id}
              d={route.d}
              fill="none"
              stroke={
                route.tone === 'matched'
                  ? 'var(--map-route-green)'
                  : 'var(--map-route-amber)'
              }
              strokeWidth={route.tone === 'matched' ? 2.5 : 2}
              strokeDasharray={route.tone === 'matched' ? '5,4' : '4,4'}
              markerEnd={`url(#arrow-${route.tone === 'matched' ? 'green' : 'amber'})`}
            />
          ))}

          {nodes.map((node) => {
            const critical = node.kind === 'critical';
            return (
              <g key={node.id}>
                <title>{node.info}</title>
                {critical && (
                  <circle cx={node.x} cy={node.y} r="14" fill="var(--error)" opacity="0.18">
                    <animate
                      attributeName="r"
                      values="8;18;8"
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
                <circle
                  cx={node.x}
                  cy={node.y}
                  r={node.kind === 'idle' ? 5 : 7}
                  fill={NODE_FILL[node.kind]}
                  stroke="var(--map-lane)"
                  strokeWidth={node.kind === 'idle' ? 0 : 2}
                />
                {node.callout && (
                  <g>
                    <rect
                      x={node.x - 24}
                      y={node.y + 12}
                      width="48"
                      height="18"
                      rx="9"
                      fill={critical ? 'var(--error)' : 'var(--map-route-amber)'}
                    />
                    <text
                      x={node.x}
                      y={node.y + 24.5}
                      textAnchor="middle"
                      fontFamily="Inter"
                      fontSize="10"
                      fontWeight="700"
                      fill="#ffffff"
                    >
                      {node.callout}
                    </text>
                  </g>
                )}
              </g>
            );
          })}
        </svg>

        <div className="map__legend t-label-sm">
          {legend.map((entry) => (
            <div key={entry.label}>
              <span className="dot" style={{ background: NODE_FILL[entry.kind] }} />
              {entry.label}
            </div>
          ))}
        </div>
      </div>

      <div className="map__banner t-body-sm">
        <span className="icon" style={{ fontSize: 16, color: 'var(--primary)' }} aria-hidden="true">
          radar
        </span>
        <span>{broadcast}</span>
        {/* Broadcasting to rescuers needs the Phase 14 dispatch API. */}
        <button type="button" disabled title="Dispatch broadcast — not wired yet">
          Dispatch Broadcast
        </button>
      </div>
    </section>
  );
}
