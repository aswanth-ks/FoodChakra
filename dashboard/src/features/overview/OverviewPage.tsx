import { useEffect, useRef, useState } from 'react';
import ConsoleLayout from '../../components/layout/ConsoleLayout';
import { readSession } from '../auth/session';
import EventsFeed from './components/EventsFeed';
import KpiRow from './components/KpiRow';
import NetworkHealth from './components/NetworkHealth';
import NetworkMap from './components/NetworkMap';
import PriorityQueue from './components/PriorityQueue';
import { SAMPLE_OVERVIEW } from './data/sampleOverview';
import type { OverviewData, PriorityCase } from './data/overviewTypes';

/** "Good evening", as the design greets. */
function greeting(now: Date): string {
  const hour = now.getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/** The design's UTC wall clock, ticking once a second. */
function useUtcClock(): string {
  const [stamp, setStamp] = useState(() => formatUtc(new Date()));

  useEffect(() => {
    const timer = window.setInterval(() => setStamp(formatUtc(new Date())), 1000);
    return () => window.clearInterval(timer);
  }, []);

  return stamp;
}

function formatUtc(date: Date): string {
  const pad = (value: number) => value.toString().padStart(2, '0');
  return `${pad(date.getUTCHours())}:${pad(date.getUTCMinutes())}:${pad(
    date.getUTCSeconds(),
  )} UTC`;
}

/**
 * "Rescue Operations Console — Overview".
 *
 * Faithful translation of the Stitch design
 * (project `8883198284374486482`, screen `6d0e54157764439abe027aefe7303a8d`).
 *
 * The one screen an operator keeps open: network state up top, the live map
 * and the cases needing a human side by side, then the trailing health
 * baselines and the event feed.
 */
export default function OverviewPage({
  data = SAMPLE_OVERVIEW,
}: {
  data?: OverviewData;
}) {
  const session = readSession();
  const clock = useUtcClock();

  const [sector, setSector] = useState(data.sectors[0] ?? 'All sectors');
  const [sectorOpen, setSectorOpen] = useState(false);
  const sectorRef = useRef<HTMLDivElement | null>(null);

  // Click-away and Escape both close the sector menu, as a desktop menu should.
  useEffect(() => {
    if (!sectorOpen) return;

    function onPointerDown(event: MouseEvent) {
      if (!sectorRef.current?.contains(event.target as Node)) {
        setSectorOpen(false);
      }
    }
    function onKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') setSectorOpen(false);
    }

    document.addEventListener('mousedown', onPointerDown);
    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('mousedown', onPointerDown);
      document.removeEventListener('keydown', onKeyDown);
    };
  }, [sectorOpen]);

  // Intervening on a case opens the dispatch drawer in the design. That drawer
  // acts on the rescue service, which does not exist yet, so the action is
  // acknowledged rather than faked.
  const [notice, setNotice] = useState<string | null>(null);

  function handleIntervene(item: PriorityCase) {
    setNotice(
      `Dispatch intervention for ${item.title} (${item.detail}) needs the ` +
        'Phase 14 rescue service — no override was sent.',
    );
  }

  return (
    <ConsoleLayout title="Rescue Operations" subtitle="Real-time rescue network">
      <section className="intro">
        <div>
          <h1 className="t-headline-lg">
            {greeting(new Date())},{' '}
            {session ? session.name : 'Operations Team'}
          </h1>
          <p className="t-body-md">
            Here’s what’s happening across the FoodLoop rescue network.
          </p>
        </div>

        <div className="intro__actions">
          <div className="menu" ref={sectorRef}>
            <button
              className="pill t-label-md"
              type="button"
              aria-haspopup="listbox"
              aria-expanded={sectorOpen}
              onClick={() => setSectorOpen((open) => !open)}
            >
              <span className="icon muted" style={{ fontSize: 16 }} aria-hidden="true">
                tune
              </span>
              {sector}
              <span className="icon muted" style={{ fontSize: 16 }} aria-hidden="true">
                keyboard_arrow_down
              </span>
            </button>

            {sectorOpen && (
              <div className="menu__list" role="listbox" aria-label="Sector">
                {data.sectors.map((option) => (
                  <button
                    key={option}
                    className="menu__option"
                    role="option"
                    aria-selected={option === sector}
                    type="button"
                    onClick={() => {
                      setSector(option);
                      setSectorOpen(false);
                    }}
                  >
                    {option}
                  </button>
                ))}
              </div>
            )}
          </div>

          <div className="pill">
            <span className="dot dot--pulse" style={{ background: 'var(--success)' }} />
            <span className="t-label-sm upper muted">Stream Active</span>
            <span style={{ color: 'var(--outline-variant)' }} aria-hidden="true">
              ·
            </span>
            <span className="t-metric" style={{ fontSize: 12 }}>
              {clock}
            </span>
          </div>
        </div>
      </section>

      {notice && (
        <div className="login__alert t-body-sm" role="status" style={{ marginTop: 0 }}>
          <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
            info
          </span>
          <span>{notice}</span>
          <button
            className="iconbtn"
            type="button"
            onClick={() => setNotice(null)}
            aria-label="Dismiss"
            style={{ marginLeft: 'auto' }}
          >
            <span className="icon" style={{ fontSize: 18 }}>
              close
            </span>
          </button>
        </div>
      )}

      <KpiRow kpis={data.kpis} />

      <section className="ops">
        <NetworkMap
          nodes={data.mapNodes}
          routes={data.mapRoutes}
          legend={data.legend}
          broadcast={data.broadcast}
        />
        <PriorityQueue
          cases={data.cases}
          footnote={data.queueFootnote}
          totalLiveQueue={data.totalLiveQueue}
          onIntervene={handleIntervene}
        />
      </section>

      <NetworkHealth metrics={data.health} />
      <EventsFeed events={data.events} />
    </ConsoleLayout>
  );
}
