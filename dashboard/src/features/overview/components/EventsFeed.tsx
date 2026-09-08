import type { EventKind, NetworkEvent } from '../data/overviewTypes';

/** Each event kind gets its own icon and colour on the timeline rail. */
const EVENT_STYLE: Record<EventKind, { icon: string; color: string }> = {
  matched: { icon: 'person_check', color: 'var(--success)' },
  completed: { icon: 'check_circle', color: 'var(--primary)' },
  escalation: { icon: 'warning', color: 'var(--warning-deep)' },
  published: { icon: 'upload', color: 'var(--on-surface-variant)' },
  verified: { icon: 'qr_code_scanner', color: 'var(--success)' },
};

/** What just happened across the network. */
export default function EventsFeed({ events }: { events: NetworkEvent[] }) {
  return (
    <section className="card" aria-label="Recent events">
      <div className="section-head">
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <h2 className="t-headline-sm" style={{ margin: 0 }}>
            Recent events
          </h2>
          <span className="chip t-label-sm muted">
            <span className="dot dot--pulse" style={{ background: 'var(--success)' }} />
            Auto-refreshing
          </span>
        </div>
        {/* Export needs the Phase 14 audit endpoint. */}
        <button className="btn btn--quiet" type="button" disabled>
          <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
            download
          </span>
          Export Audit Log
        </button>
      </div>

      <div className="events__list">
        {events.map((event) => {
          const style = EVENT_STYLE[event.kind];
          return (
            <article className="event" key={`${event.time}-${event.title}`}>
              <span className="t-metric muted" style={{ fontSize: 12 }}>
                {event.time}
              </span>

              <span className="event__rail">
                <span
                  className="icon"
                  style={{ fontSize: 16, color: style.color }}
                  aria-hidden="true"
                >
                  {style.icon}
                </span>
              </span>

              <div className="event__body">
                <div className="t-body-md" style={{ fontWeight: 600 }}>
                  {event.title}
                </div>
                <div className="t-body-sm truncate">{event.subject}</div>
                <div className="t-body-sm event__note truncate">({event.note})</div>
              </div>

              <span className="t-label-sm muted">{event.ago}</span>
            </article>
          );
        })}
      </div>
    </section>
  );
}
