import {
  LIFECYCLE_LABEL,
  LIFECYCLE_ORDER,
  type LifecycleEntry,
} from '../data/rescueTypes';

/**
 * The nine-step horizontal lifecycle tracker.
 *
 * Steps before the current one are done, the current one is live, and the
 * rest are pending — which is what the design's tick / icon / number
 * treatment encodes.
 */
export default function LifecycleTimeline({
  entries,
  currentIndex,
}: {
  entries: LifecycleEntry[];
  currentIndex: number;
}) {
  return (
    <ol className="lifecycle" aria-label="Rescue lifecycle">
      {entries.map((entry, index) => {
        const done = index < currentIndex;
        const current = index === currentIndex;
        const state = done ? 'done' : current ? 'current' : 'pending';

        return (
          <li className={`lifecycle__step lifecycle__step--${state}`} key={entry.step}>
            <div className="lifecycle__rail" aria-hidden="true">
              <span className="lifecycle__line lifecycle__line--before" />
              <span className="lifecycle__marker">
                {done ? (
                  <span className="icon" style={{ fontSize: 14 }}>
                    check
                  </span>
                ) : current ? (
                  <span className="icon" style={{ fontSize: 14 }}>
                    search
                  </span>
                ) : (
                  <span className="t-label-sm">
                    {LIFECYCLE_ORDER.indexOf(entry.step) + 1}
                  </span>
                )}
              </span>
              <span className="lifecycle__line lifecycle__line--after" />
            </div>

            <span className="lifecycle__label t-label-sm">
              {LIFECYCLE_LABEL[entry.step]}
            </span>
            <span className="lifecycle__stamp t-label-sm">{entry.stamp}</span>
          </li>
        );
      })}
    </ol>
  );
}
