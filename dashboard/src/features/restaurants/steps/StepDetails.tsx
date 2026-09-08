import OnboardingStepper from '../components/OnboardingStepper';
import { ONBOARDING_CONFIG } from '../data/sampleOnboarding';
import {
  RESTAURANT_CATEGORIES,
  detailsComplete,
  type OnboardingDraft,
  type RestaurantCategory,
} from '../data/onboardingTypes';

/**
 * "Restaurant Onboarding: Step 1 — Restaurant Details".
 *
 * Faithful translation of the Stitch design
 * (screen `7ef47ae53bc945adb7a1444678d3d754`).
 *
 * Establishes the physical site and its dispatch contact. Deliberately no
 * credentials here — those are step 2.
 */
export default function StepDetails({
  draft,
  onChange,
  onCancel,
  onNext,
}: {
  draft: OnboardingDraft;
  onChange: (patch: Partial<OnboardingDraft>) => void;
  onCancel: () => void;
  onNext: () => void;
}) {
  const ready = detailsComplete(draft);
  const config = ONBOARDING_CONFIG;

  return (
    <>
      <OnboardingStepper current={1} />

      <article className="card">
        <div className="section-head">
          <div>
            <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                storefront
              </span>
              Restaurant Information
            </h2>
            <span className="t-body-sm muted">
              Enter the primary operating entity details for network inventory
              routing.
            </span>
          </div>
          <span className="chip t-label-sm" style={{
            background: 'var(--secondary-container)',
            color: 'var(--primary)',
          }}>
            Required Phase 1
          </span>
        </div>

        <div className="formgrid">
          <Field
            label="Restaurant / Business Name"
            required
            hint="Legal name registered on local food handling documentation"
            value={draft.businessName}
            onChange={(value) => onChange({ businessName: value })}
            placeholder="Green Leaf Kitchen"
          />
          <Field
            label="Branch Name / Unit ID"
            required
            hint="Distinguishes multiple sites under a single food operator holding"
            value={draft.branchName}
            onChange={(value) => onChange({ branchName: value })}
            placeholder="Downtown Branch (GLK-DT-01)"
          />

          <div className="field">
            <label className="t-label-md" htmlFor="onb-category">
              Restaurant Category <span className="req">*</span>
            </label>
            <select
              id="onb-category"
              className="select"
              value={draft.category}
              onChange={(event) =>
                onChange({ category: event.target.value as RestaurantCategory })
              }
            >
              {RESTAURANT_CATEGORIES.map((option) => (
                <option key={option} value={option}>
                  {option}
                </option>
              ))}
            </select>
            <span className="t-body-sm muted">
              Defines surplus volume expectations and packaging profiles
            </span>
          </div>

          <Field
            label="Operating Area / District Zone"
            required
            hint="Determines dispatcher geofencing and bicycle courier radius"
            value={draft.operatingArea}
            onChange={(value) => onChange({ operatingArea: value })}
            placeholder="Downtown District (Zone 03)"
          />

          <div className="formgrid__wide">
            <Field
              label="Pickup Location & Dispatch Instructions"
              badge="Optional / Highly Recommended"
              hint="Included in dispatched courier instructions immediately upon rescue acceptance"
              value={draft.pickupLocation}
              onChange={(value) => onChange({ pickupLocation: value })}
              placeholder="Main pickup counter (rear loading dock)"
            />
          </div>
        </div>
      </article>

      <article className="card">
        <div className="section-head">
          <div>
            <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                contact_phone
              </span>
              Authorized Operational Contact
            </h2>
            <span className="t-body-sm muted">
              Designate the direct line for time-critical rescue coordination
              and gate pass verification.
            </span>
          </div>
          <span className="chip t-label-sm" style={{
            background: 'var(--surface-container-low)',
            color: 'var(--on-surface-variant)',
          }}>
            Coordination
          </span>
        </div>

        <div className="formgrid">
          <Field
            label="Authorized Contact Full Name"
            required
            hint="Title or on-site role (GM, Head Chef, Operations Lead)"
            value={draft.contactName}
            onChange={(value) => onChange({ contactName: value })}
            placeholder="Marcus Vance"
          />
          <Field
            label="On-site Role"
            hint="Shown to couriers during handover"
            value={draft.contactRole}
            onChange={(value) => onChange({ contactRole: value })}
            placeholder="General Manager"
          />
          <div className="formgrid__wide">
            <Field
              label="Direct Emergency / Kitchen Phone"
              required
              type="tel"
              hint="Used exclusively for urgent dispatch coordination and physical handover verification"
              value={draft.phone}
              onChange={(value) => onChange({ phone: value })}
              placeholder="+1 (555) 382-9104"
            />
          </div>
        </div>

        <div className="alertcard alertcard--neutral">
          <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
            info
          </span>
          <div>
            <div className="t-body-md" style={{ fontWeight: 600 }}>
              Looking for operator login &amp; portal invitation?
            </div>
            <div className="t-body-sm muted">
              Login credentials and dashboard access are configured in{' '}
              <strong>Step 2: Access Details</strong>. Step 1 solely
              establishes the physical location and operational
              point-of-contact for dispatch telemetry.
            </div>
          </div>
        </div>
      </article>

      <article className="card">
        <div className="section-head">
          <div>
            <h2 className="t-headline-sm cardtitle" style={{ margin: 0 }}>
              <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
                policy
              </span>
              Rescue Participation Setup
            </h2>
            <span className="t-body-sm muted">
              Default baseline parameters applied to this partner profile upon
              registration.
            </span>
          </div>
          <span className="t-label-sm muted">Preset Baseline</span>
        </div>

        <div className="statgrid">
          {config.baseline.map((parameter) => (
            <div className="statgrid__cell" key={parameter.label}>
              <span className="t-label-sm upper muted">{parameter.label}</span>
              <span className="dtable__state t-body-md" style={{ fontWeight: 600 }}>
                <span
                  className="icon"
                  style={{ fontSize: 16, color: 'var(--primary)' }}
                  aria-hidden="true"
                >
                  {parameter.icon}
                </span>
                {parameter.value}
              </span>
              <span className="t-body-sm muted">{parameter.caption}</span>
            </div>
          ))}
        </div>

        <div className="alertcard alertcard--good">
          <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
            verified
          </span>
          <div className="t-body-sm">{config.baselineNote}</div>
        </div>
      </article>

      <div className="wizardbar">
        <span className="t-body-sm muted dtable__state">
          <span className="icon" style={{ fontSize: 16 }} aria-hidden="true">
            lock
          </span>
          All required fields must be complete before advancing to Step 2.
        </span>
        <span className="wizardbar__actions">
          <button className="btn btn--quiet" type="button" onClick={onCancel}>
            Cancel
          </button>
          <button
            className="btn btn--primary"
            type="button"
            disabled={!ready}
            onClick={onNext}
          >
            Next: Access Details
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              arrow_forward
            </span>
          </button>
        </span>
      </div>
    </>
  );
}

function Field({
  label,
  required,
  badge,
  hint,
  value,
  onChange,
  placeholder,
  type = 'text',
}: {
  label: string;
  required?: boolean;
  badge?: string;
  hint: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  type?: string;
}) {
  const id = `onb-${label.replace(/[^a-z]+/gi, '-').toLowerCase()}`;
  return (
    <div className="field">
      <label className="t-label-md" htmlFor={id}>
        {label} {required && <span className="req">*</span>}
        {badge && <span className="t-label-sm muted"> · {badge}</span>}
      </label>
      <input
        id={id}
        type={type}
        value={value}
        placeholder={placeholder}
        onChange={(event) => onChange(event.target.value)}
      />
      <span className="t-body-sm muted">{hint}</span>
    </div>
  );
}
