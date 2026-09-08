import OnboardingStepper from '../components/OnboardingStepper';
import { ONBOARDING_CONFIG } from '../data/sampleOnboarding';
import type { OnboardingDraft } from '../data/onboardingTypes';

/** Which of the design's three views is showing. */
export type GrantState = 'review' | 'granted' | 'conflict';

/**
 * "Restaurant Onboarding: Step 3 — Review & Grant Access".
 *
 * Faithful translation of the Stitch design
 * (screen `0af8dfeeed2c44ecb8fd00e28a0f9f08`), including its success and
 * conflict states.
 *
 * **Design divergence:** the mock carries a floating "State Preview Controls"
 * pill bar for flipping between its three views. That is a presentation aid
 * for the mock, not an operator control, so it is omitted; the states are
 * reached the way they would really occur — granting, or the collision
 * detected at step 2.
 */
export default function StepReview({
  draft,
  state,
  onBack,
  onGrant,
  onEditDetails,
  onEditAccess,
  onOnboardAnother,
  onViewAll,
  onResend,
  resendNotice,
}: {
  draft: OnboardingDraft;
  state: GrantState;
  onBack: () => void;
  onGrant: () => void;
  onEditDetails: () => void;
  onEditAccess: () => void;
  onOnboardAnother: () => void;
  onViewAll: () => void;
  onResend: () => void;
  resendNotice: string | null;
}) {
  const config = ONBOARDING_CONFIG;
  const email = draft.loginEmail.trim();

  if (state === 'granted') {
    return (
      <>
        <OnboardingStepper current={3} />

        <section className="card successhero">
          <span className="successhero__mark icon" aria-hidden="true">
            check_circle
          </span>
          <div>
            <div className="t-label-sm upper" style={{ opacity: 0.8 }}>
              Provisioning Successful
            </div>
            <h2 className="t-headline-lg" style={{ margin: '2px 0 4px' }}>
              Restaurant access granted
            </h2>
            <p className="t-body-md" style={{ margin: 0, opacity: 0.9 }}>
              {draft.businessName} has been added to FoodLoop and assigned to{' '}
              {draft.operatingArea || 'its operating zone'}.
            </p>
          </div>
        </section>

        <section className="kpis">
          <StatusCard label="Partner Status" value="Active" caption="Node provisioned" />
          <StatusCard
            label="Dashboard Access"
            value="Invitation Sent"
            caption="Role: Restaurant Partner"
          />
          <StatusCard label="Login Email" value={email} caption="HMAC token sealed" small />
          <StatusCard
            label="Next Step"
            value="Awaiting activation"
            caption="48h window"
          />
        </section>

        <section className="card">
          <div className="alertcard alertcard--good" style={{ margin: 16 }}>
            <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
              mark_email_read
            </span>
            <div style={{ flex: 1 }}>
              <div className="t-body-md" style={{ fontWeight: 600 }}>
                Activation email sent
              </div>
              <div className="t-body-sm">
                Cryptographic token expires in 48 hours • Delivery ID:
                #MSG-8839-GLK
              </div>
              {resendNotice && (
                <div className="t-body-sm" style={{ marginTop: 6 }}>
                  {resendNotice}
                </div>
              )}
            </div>
            <button className="btn btn--quiet" type="button" onClick={onResend}>
              <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                refresh
              </span>
              Resend Dispatch
            </button>
          </div>
        </section>

        <div className="wizardbar">
          {/* The per-partner profile page is not built yet; the directory is. */}
          <button
            className="btn btn--quiet"
            type="button"
            disabled
            title="Restaurant profile — not built yet"
          >
            View Restaurant Profile →
          </button>
          <span className="wizardbar__actions">
            <button
              className="btn btn--quiet"
              type="button"
              onClick={onViewAll}
            >
              View All Restaurants (248 Active Nodes)
            </button>
            <button className="btn btn--primary" type="button" onClick={onOnboardAnother}>
              <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
                add
              </span>
              Onboard Another Restaurant
            </button>
          </span>
        </div>
      </>
    );
  }

  if (state === 'conflict') {
    return (
      <>
        <OnboardingStepper current={3} />

        <section className="card">
          <div className="section-head">
            <h2 className="t-headline-sm cardtitle" style={{ margin: 0, color: 'var(--error)' }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                error
              </span>
              Account Registration Conflict
            </h2>
            <span className="chip t-label-sm" style={{
              background: 'var(--error-container)',
              color: 'var(--on-error-container)',
            }}>
              409 Conflict
            </span>
          </div>

          <div style={{ padding: 16 }}>
            <p className="t-body-md" style={{ margin: 0 }}>
              The email address <strong>{email}</strong> is already linked to
              active partner node #{config.conflictAccountId} (
              {config.conflictNodeName}).
            </p>

            <div className="t-label-sm upper muted" style={{ marginTop: 16 }}>
              Recommended operator interventions
            </div>
            <ul className="caps" style={{ marginTop: 8 }}>
              {config.conflictSuggestions.map((suggestion) => (
                <li key={suggestion}>
                  <span
                    className="icon"
                    style={{ fontSize: 16, color: 'var(--primary)' }}
                    aria-hidden="true"
                  >
                    check_small
                  </span>
                  <span className="t-body-sm">{suggestion}</span>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <div className="wizardbar">
          <button className="btn btn--quiet" type="button" onClick={onViewAll}>
            Cancel Provisioning
          </button>
          <button className="btn btn--primary" type="button" onClick={onEditAccess}>
            Edit Access Details
          </button>
        </div>
      </>
    );
  }

  return (
    <>
      <OnboardingStepper current={3} />

      <article className="card">
        <div className="section-head">
          <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
            <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
              storefront
            </span>
            Restaurant Information
          </h2>
          <button className="linkbtn t-label-md" type="button" onClick={onEditDetails}>
            Edit details →
          </button>
        </div>

        <dl className="factlist">
          <ReviewRow label="Restaurant / Business Name" value={draft.businessName} verified />
          <ReviewRow label="Branch Name / Unit ID" value={draft.branchName} />
          <ReviewRow label="Restaurant Category" value={draft.category} />
          <ReviewRow label="Operating Area" value={draft.operatingArea} />
          <ReviewRow label="Pickup Location" value={draft.pickupLocation || 'Not provided'} />
          <ReviewRow
            label="Authorized Operational Contact"
            value={
              draft.contactRole
                ? `${draft.contactName} (${draft.contactRole})`
                : draft.contactName
            }
          />
          <ReviewRow label="Direct Business Phone" value={draft.phone} />
          <ReviewRow
            label="Rescue Participation"
            value="Active Pipeline · Direct Handover Standard"
          />
        </dl>
      </article>

      <article className="card">
        <div className="section-head">
          <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
            <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
              vpn_key
            </span>
            Dashboard Access &amp; Permissions
          </h2>
          <button className="linkbtn t-label-md" type="button" onClick={onEditAccess}>
            Edit access →
          </button>
        </div>

        <dl className="factlist">
          <ReviewRow label="Authorized Login Email" value={email} verified />
          <ReviewRow label="Assigned Role" value={config.roleTitle} />
          <ReviewRow label="Provisioned Console" value="FoodLoop Restaurant Dashboard" />
          <ReviewRow
            label="Access Scope"
            value="Surplus publishing, live courier monitoring, QR handshake signatures"
          />
          <ReviewRow
            label="Password Management"
            value="Zero-Password Architecture"
          />
          <ReviewRow
            label="Initial Access State"
            value="Pending operator grant & email dispatch (48h token validity)"
          />
        </dl>

        <div className="alertcard alertcard--good">
          <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
            lock_person
          </span>
          <div className="t-body-sm">
            Partner creates their password securely via the activation email.
            Desk operators never handle raw passwords.
          </div>
        </div>
      </article>

      <article className="card">
        <div className="section-head">
          <div>
            <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                alt_route
              </span>
              What happens next?
            </h2>
            <span className="t-body-sm muted">
              Cryptographic credential generation and automated dispatch
              lifecycle.
            </span>
          </div>
        </div>

        <ol className="funnel" style={{ gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' }}>
          <NextStep
            index={1}
            title="Restaurant account created"
            body={`FoodLoop creates the merchant record and binds the ${
              draft.operatingArea || 'assigned'
            } routing zone.`}
            arrow
          />
          <NextStep
            index={2}
            title="Secure activation link dispatched"
            body={`Signed HMAC-256 activation email sent to ${email}.`}
            arrow
          />
          <NextStep
            index={3}
            title="Partner sets credentials"
            body="Restaurant manager sets password and 2FA, then logs into the Restaurant Dashboard."
          />
        </ol>

        <div className="alertcard alertcard--neutral">
          <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
            info
          </span>
          <div className="t-body-sm">
            FoodLoop desk operators never view or handle passwords. The account
            is only provisioned upon clicking <strong>Grant Access</strong>.
          </div>
        </div>
      </article>

      <article className="card">
        <div className="section-head">
          <div>
            <h2 className="t-headline-sm" style={{ margin: 0 }}>
              Ready to grant access
            </h2>
            <span className="t-body-sm muted">
              FoodLoop will create this restaurant partner account and send a
              secure activation email to {email}.
            </span>
          </div>
        </div>

        <div className="statgrid" style={{ gridTemplateColumns: 'repeat(3, minmax(0, 1fr))' }}>
          <div className="statgrid__cell">
            <span className="t-label-sm upper muted">Entity</span>
            <span className="t-body-md" style={{ fontWeight: 600 }}>
              {draft.businessName}
            </span>
            <span className="t-body-sm muted">{draft.branchName}</span>
          </div>
          <div className="statgrid__cell">
            <span className="t-label-sm upper muted">Login Target</span>
            <span className="t-body-md truncate" style={{ fontWeight: 600 }}>
              {email}
            </span>
            <span className="t-body-sm muted">Token: 48h active</span>
          </div>
          <div className="statgrid__cell">
            <span className="t-label-sm upper muted">Assigned Access</span>
            <span className="t-body-md" style={{ fontWeight: 600 }}>
              Restaurant Partner
            </span>
            <span className="t-body-sm muted">Console Standard Tier</span>
          </div>
        </div>
      </article>

      <div className="wizardbar">
        <button className="btn btn--quiet" type="button" onClick={onBack}>
          <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
            arrow_back
          </span>
          Back to Access Details
        </button>
        <button className="btn btn--primary" type="button" onClick={onGrant}>
          Grant Access
          <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
            arrow_forward
          </span>
        </button>
      </div>
    </>
  );
}

function ReviewRow({
  label,
  value,
  verified,
}: {
  label: string;
  value: string;
  verified?: boolean;
}) {
  return (
    <div className="factlist__row">
      <dt className="t-body-sm muted">{label}</dt>
      <dd className="t-body-md">
        {value || '—'}
        {verified && (
          <span
            className="icon"
            style={{ fontSize: 15, color: 'var(--success)', marginLeft: 6, verticalAlign: 'middle' }}
            aria-label="Verified"
          >
            verified
          </span>
        )}
      </dd>
    </div>
  );
}

function NextStep({
  index,
  title,
  body,
  arrow,
}: {
  index: number;
  title: string;
  body: string;
  arrow?: boolean;
}) {
  return (
    <li className="funnel__stage">
      <span className="wizard__marker wizard__marker--sm">{index}</span>
      <div className="t-body-md" style={{ fontWeight: 600, marginTop: 6 }}>
        {title}
      </div>
      <div className="t-body-sm muted">{body}</div>
      {arrow && (
        <span className="funnel__arrow icon" aria-hidden="true">
          chevron_right
        </span>
      )}
    </li>
  );
}

function StatusCard({
  label,
  value,
  caption,
  small,
}: {
  label: string;
  value: string;
  caption: string;
  small?: boolean;
}) {
  return (
    <article className="card kpi">
      <div className="kpi__head">
        <span className="t-label-sm upper muted">{label}</span>
      </div>
      <div
        className={small ? 't-body-md truncate' : 't-headline-sm'}
        style={{ fontWeight: 600, color: 'var(--primary)' }}
      >
        {value}
      </div>
      <div className="kpi__foot t-body-sm truncate">{caption}</div>
    </article>
  );
}
