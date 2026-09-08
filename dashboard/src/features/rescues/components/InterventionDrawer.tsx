import { useEffect, useRef, useState } from 'react';
import type { RescueDetail } from '../data/rescueTypes';

/**
 * The slide-over an operator uses to force a resolution.
 *
 * The choice is real UI, but applying it needs the Phase 14 rescue service,
 * so confirming reports what *would* be sent rather than pretending an
 * override went out.
 */
export default function InterventionDrawer({
  detail,
  open,
  onClose,
  onApply,
}: {
  detail: RescueDetail;
  open: boolean;
  onClose: () => void;
  onApply: (optionTitle: string, note: string) => void;
}) {
  const [choice, setChoice] = useState(
    detail.interventionOptions.find((option) => option.recommended)?.id ??
      detail.interventionOptions[0]?.id ??
      '',
  );
  const [note, setNote] = useState('');
  const panelRef = useRef<HTMLDivElement | null>(null);

  // Escape closes, and focus moves into the drawer so keyboard users are not
  // left behind the scrim.
  useEffect(() => {
    if (!open) return;

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') onClose();
    }
    document.addEventListener('keydown', onKeyDown);
    panelRef.current?.focus();

    return () => document.removeEventListener('keydown', onKeyDown);
  }, [open, onClose]);

  if (!open) return null;

  const selected = detail.interventionOptions.find(
    (option) => option.id === choice,
  );

  return (
    <div className="scrim" role="presentation" onMouseDown={onClose}>
      <div
        className="drawer"
        role="dialog"
        aria-modal="true"
        aria-label="Rescue intervention"
        tabIndex={-1}
        ref={panelRef}
        onMouseDown={(event) => event.stopPropagation()}
      >
        <header className="drawer__head">
          <div>
            <div className="t-label-sm upper" style={{ color: 'var(--error)' }}>
              Priority Escalation
            </div>
            <h2 className="t-headline-sm" style={{ margin: '2px 0 0' }}>
              Rescue Intervention
            </h2>
            <div className="t-body-sm muted">
              Incident #{detail.reference} · {detail.partner}
            </div>
          </div>
          <button className="iconbtn" type="button" onClick={onClose} aria-label="Close">
            <span className="icon" style={{ fontSize: 20 }}>
              close
            </span>
          </button>
        </header>

        <div className="drawer__body">
          <div className="alertcard alertcard--error">
            <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
              report
            </span>
            <div>
              <div className="t-body-md" style={{ fontWeight: 600 }}>
                {detail.interventionTrigger}
              </div>
              <div className="t-body-sm">{detail.interventionTriggerBody}</div>
            </div>
          </div>

          <fieldset className="drawer__fieldset">
            <legend className="t-label-md upper muted">
              Select Intervention Protocol
            </legend>

            {detail.interventionOptions.map((option) => (
              <label
                key={option.id}
                className={`protocol${choice === option.id ? ' protocol--on' : ''}`}
              >
                <input
                  type="radio"
                  name="intervention-protocol"
                  value={option.id}
                  checked={choice === option.id}
                  onChange={() => setChoice(option.id)}
                />
                <span className="protocol__body">
                  <span className="protocol__title">
                    <span className="t-body-md" style={{ fontWeight: 600 }}>
                      {option.title}
                    </span>
                    {option.recommended && (
                      <span
                        className="chip t-label-sm"
                        style={{
                          background: 'var(--primary-fixed)',
                          color: 'var(--on-primary-fixed)',
                        }}
                      >
                        Recommended
                      </span>
                    )}
                  </span>
                  <span className="t-body-sm muted">{option.description}</span>
                  <span className="t-label-sm" style={{ color: 'var(--primary)' }}>
                    {option.footnote}
                  </span>
                </span>
              </label>
            ))}
          </fieldset>

          <div className="field">
            <label className="t-label-md" htmlFor="dispatch-note">
              Operator Internal Dispatch Note
            </label>
            <textarea
              id="dispatch-note"
              rows={3}
              value={note}
              onChange={(event) => setNote(event.target.value)}
              placeholder="Note to couriers…"
            />
          </div>
        </div>

        <footer className="drawer__foot">
          <button className="btn btn--quiet" type="button" onClick={onClose}>
            Cancel
          </button>
          <button
            className="btn btn--danger"
            type="button"
            disabled={!selected}
            onClick={() => selected && onApply(selected.title, note)}
          >
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              send
            </span>
            Apply Intervention
          </button>
        </footer>
      </div>
    </div>
  );
}
