import OnboardingStepper from '../components/OnboardingStepper';
import { ONBOARDING_CONFIG } from '../data/sampleOnboarding';
import {
  emailDomain,
  isEmailValid,
  type OnboardingDraft,
} from '../data/onboardingTypes';

/**
 * "Restaurant Onboarding: Step 2 — Access Details".
 *
 * Faithful translation of the Stitch design
 * (screen `ab93f88ddd2c4670aad9771485e0803d`).
 *
 * Stages *who* gets the activation link and *what* they will be allowed to
 * do. No password is set here, by design — see the zero-password card.
 */
export default function StepAccess({
  draft,
  onChange,
  simulateConflict,
  onSimulateConflict,
  onBack,
  onNext,
}: {
  draft: OnboardingDraft;
  onChange: (patch: Partial<OnboardingDraft>) => void;
  /** The design ships an operator toggle for exercising the collision path. */
  simulateConflict: boolean;
  onSimulateConflict: (value: boolean) => void;
  onBack: () => void;
  onNext: () => void;
}) {
  const config = ONBOARDING_CONFIG;
  const email = draft.loginEmail.trim();
  const valid = isEmailValid(email);
  const domain = emailDomain(email);
  const ready = valid && !simulateConflict;

  return (
    <>
      <OnboardingStepper current={2} />

      <section className="card stagingbanner">
        <span className="icon" style={{ fontSize: 22, color: 'var(--primary)' }} aria-hidden="true">
          restaurant
        </span>
        <div style={{ minWidth: 0, flex: 1 }}>
          <div className="t-body-lg" style={{ fontWeight: 600 }}>
            {draft.businessName || 'Unnamed restaurant'}
            <span className="muted" style={{ fontWeight: 400 }}>
              {draft.branchName ? ` · ${draft.branchName}` : ''}
            </span>
          </div>
          <div className="t-body-sm muted">
            Entity ID: {config.entityId} • Assigned Dispatch Hub:{' '}
            {config.dispatchHub}
          </div>
        </div>
        <span className="chip t-label-sm" style={{
          background: 'var(--primary-fixed)',
          color: 'var(--on-primary-fixed)',
        }}>
          <span className="icon" style={{ fontSize: 13 }} aria-hidden="true">
            check
          </span>
          Step 1 Validated
        </span>
      </section>

      <section className="card simbar">
        <span className="t-label-sm muted dtable__state">
          <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
            tune
          </span>
          Validation Engine State:
        </span>
        <div className="segmented" role="group" aria-label="Validation engine state">
          <button
            type="button"
            className={`segmented__btn t-label-md${!simulateConflict ? ' segmented__btn--on' : ''}`}
            aria-pressed={!simulateConflict}
            onClick={() => onSimulateConflict(false)}
          >
            Clean Registry
          </button>
          <button
            type="button"
            className={`segmented__btn t-label-md${simulateConflict ? ' segmented__btn--on' : ''}`}
            aria-pressed={simulateConflict}
            onClick={() => onSimulateConflict(true)}
          >
            Simulate Conflict
          </button>
        </div>
      </section>

      <article className="card">
        <div className="section-head">
          <div>
            <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                alternate_email
              </span>
              Dashboard Access
            </h2>
            <span className="t-body-sm muted">
              Choose the authorized email that will receive the secure account
              activation invitation.
            </span>
          </div>
          <span className="chip t-label-sm" style={{
            background: 'var(--secondary-container)',
            color: 'var(--primary)',
          }}>
            Required Field
          </span>
        </div>

        <div className="formgrid">
          <div className="formgrid__wide">
            <div className={`field${email && !valid ? ' field--invalid' : ''}`}>
              <label className="t-label-md" htmlFor="onb-email">
                Authorized Login Email <span className="req">*</span>
              </label>
              <input
                id="onb-email"
                type="email"
                value={draft.loginEmail}
                placeholder="operations@greenleafkitchen.com"
                onChange={(event) => onChange({ loginEmail: event.target.value })}
                aria-describedby="onb-email-status"
              />
              <span className="t-body-sm muted" id="onb-email-status">
                {email.length === 0 ? (
                  'Primary administrative credential.'
                ) : valid ? (
                  <span className="dtable__state" style={{ color: 'var(--success)' }}>
                    <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                      check_circle
                    </span>
                    Format valid · this address receives the activation link.
                    Token expires 48 hours after dispatch.
                  </span>
                ) : (
                  <span className="field__error">
                    Enter a valid email address.
                  </span>
                )}
              </span>
            </div>
          </div>
        </div>

        {valid && !simulateConflict && (
          <div className="alertcard alertcard--good">
            <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
              verified_user
            </span>
            <div>
              <div className="t-body-md" style={{ fontWeight: 600 }}>
                Checked: no conflicting FoodLoop account detected
              </div>
              <div className="t-body-sm">
                The domain {domain} has 0 registered partner consoles in
                region. Free to provision.
              </div>
            </div>
          </div>
        )}

        {valid && simulateConflict && (
          <div className="alertcard alertcard--error" style={{ margin: '0 16px 16px' }}>
            <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
              warning
            </span>
            <div>
              <div className="t-body-md" style={{ fontWeight: 600 }}>
                Account collision warning
              </div>
              <div className="t-body-sm">
                This email is already associated with an active FoodLoop
                restaurant console (FL-ACC-0914). A single email cannot be
                bound to two separate branch tenant records.
              </div>
            </div>
          </div>
        )}
      </article>

      <article className="card">
        <div className="section-head">
          <div>
            <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                badge
              </span>
              Access Role &amp; Permission Tier
            </h2>
            <span className="t-body-sm muted">
              Assign the operational permission scope within the FoodLoop
              rescue network.
            </span>
          </div>
          <span className="t-label-sm muted">Standard Policy</span>
        </div>

        <div className="rolecard">
          <div className="rolecard__head">
            <span className="icon" style={{ fontSize: 20, color: 'var(--primary)' }} aria-hidden="true">
              storefront
            </span>
            <div style={{ minWidth: 0, flex: 1 }}>
              <div className="t-body-md" style={{ fontWeight: 600 }}>
                {config.roleTitle}
              </div>
              <div className="t-body-sm muted">{config.roleCaption}</div>
            </div>
            <span className="chip t-label-sm" style={{
              background: 'var(--primary-fixed)',
              color: 'var(--on-primary-fixed)',
            }}>
              Scoped
            </span>
          </div>

          <div className="t-label-sm muted dtable__state" style={{ marginTop: 8 }}>
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              lock_clock
            </span>
            {config.roleConsole}
          </div>

          <div className="t-label-sm upper muted" style={{ marginTop: 12 }}>
            Granted capabilities
          </div>
          <ul className="caps">
            {config.capabilities.map((capability) => (
              <li key={capability}>
                <span
                  className="icon"
                  style={{ fontSize: 16, color: 'var(--success)' }}
                  aria-hidden="true"
                >
                  check_circle
                </span>
                <span className="t-body-sm">{capability}</span>
              </li>
            ))}
          </ul>
        </div>

        <div className="alertcard alertcard--neutral">
          <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
            info
          </span>
          <div className="t-body-sm">{config.roleNote}</div>
        </div>
      </article>

      <article className="card">
        <div className="section-head">
          <div>
            <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                shield_person
              </span>
              Account Activation Protocol
            </h2>
            <span className="t-body-sm muted">
              Cryptographic token generation and zero-knowledge provisioning
              flow.
            </span>
          </div>
        </div>

        <div className="alertcard alertcard--good">
          <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
            key
          </span>
          <div>
            <div className="t-body-md" style={{ fontWeight: 600 }}>
              {config.zeroPasswordTitle}
            </div>
            <div className="t-body-sm" style={{ fontWeight: 600 }}>
              {config.zeroPasswordLead}
            </div>
            <div className="t-body-sm" style={{ marginTop: 4 }}>
              {config.zeroPasswordBody}
            </div>
          </div>
        </div>

        <div className="t-label-sm upper muted" style={{ padding: '0 16px' }}>
          Invitation dispatch &amp; credential lifecycle
        </div>
        <ol className="funnel" style={{ gridTemplateColumns: 'repeat(4, minmax(0, 1fr))' }}>
          {config.lifecycle.map((stage, index) => (
            <li className="funnel__stage" key={stage.index}>
              <div className="funnel__head">
                <span className="wizard__marker wizard__marker--sm">
                  {stage.index}
                </span>
                <span className="t-label-sm upper muted">{stage.tag}</span>
              </div>
              <div className="t-body-md" style={{ fontWeight: 600 }}>
                {stage.title}
              </div>
              <div className="t-body-sm muted">{stage.body}</div>
              {index < config.lifecycle.length - 1 && (
                <span className="funnel__arrow icon" aria-hidden="true">
                  chevron_right
                </span>
              )}
            </li>
          ))}
        </ol>
      </article>

      <article className="card">
        <div className="section-head">
          <div>
            <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                preview
              </span>
              Access Preview
            </h2>
            <span className="t-body-sm muted">
              Verifying staging configuration prior to final review and
              activation generation.
            </span>
          </div>
          <span className="t-label-sm muted dtable__state">
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              lock
            </span>
            256-Bit TLS Staged
          </span>
        </div>

        <div className="statgrid">
          <PreviewCell
            label="Restaurant Entity"
            value={draft.businessName || '—'}
            caption={`${draft.branchName || 'Branch pending'} · Staged from Step 1`}
          />
          <PreviewCell
            label="Operational Contact"
            value={draft.contactName || '—'}
            caption={[draft.contactRole, draft.phone].filter(Boolean).join(' · ') || 'Pending'}
          />
          <PreviewCell
            label="Authorized Login Email"
            value={email || '—'}
            caption={valid ? 'Ready for link dispatch' : 'Awaiting a valid address'}
          />
          <PreviewCell
            label="Provisioned Target"
            value="FoodLoop Restaurant Console"
            caption="Web & Tablet Station View"
          />
          <PreviewCell
            label="Assigned Security Tier"
            value="Restaurant Partner (Standard)"
            caption="Surplus Publishing + Courier PIN"
          />
          <PreviewCell
            label="Initial Access State"
            value="Pending Step 3 Dispatch"
            caption="Link expires in 48 hrs"
          />
        </div>
      </article>

      <div className="wizardbar">
        <button className="btn btn--quiet" type="button" onClick={onBack}>
          <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
            arrow_back
          </span>
          Back to Restaurant Details
        </button>
        <span className="wizardbar__actions">
          <span className="t-body-sm muted dtable__state">
            <span
              className="icon"
              style={{ fontSize: 16, color: ready ? 'var(--success)' : undefined }}
              aria-hidden="true"
            >
              {ready ? 'verified' : 'pending'}
            </span>
            {ready
              ? 'Email format verified · ready to proceed to final review'
              : simulateConflict
                ? 'Resolve the account collision to continue'
                : 'A valid authorized email is required'}
          </span>
          <button
            className="btn btn--primary"
            type="button"
            disabled={!ready}
            onClick={onNext}
          >
            Next: Review &amp; Grant Access
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              arrow_forward
            </span>
          </button>
        </span>
      </div>
    </>
  );
}

function PreviewCell({
  label,
  value,
  caption,
}: {
  label: string;
  value: string;
  caption: string;
}) {
  return (
    <div className="statgrid__cell">
      <span className="t-label-sm upper muted">{label}</span>
      <span className="t-body-md truncate" style={{ fontWeight: 600 }}>
        {value}
      </span>
      <span className="t-body-sm muted">{caption}</span>
    </div>
  );
}
