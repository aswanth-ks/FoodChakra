import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import ConsoleLayout, {
  ConsoleStatusStrip,
} from '../../components/layout/ConsoleLayout';
import StepAccess from './steps/StepAccess';
import StepDetails from './steps/StepDetails';
import StepReview, { type GrantState } from './steps/StepReview';
import { ONBOARDING_CONFIG } from './data/sampleOnboarding';
import { EMPTY_DRAFT, type OnboardingDraft } from './data/onboardingTypes';
import { SAMPLE_NETWORK_STATUS } from '../rescues/data/sampleRescues';
import type { NetworkStatus } from '../rescues/data/rescueTypes';

/**
 * Restaurant onboarding, steps 1-3.
 *
 * This is the console side of partner access: granting here is what would
 * later let that restaurant sign in to the partner app. **Nothing is
 * provisioned yet** — no account is created, no email is dispatched, and the
 * "granted" state is a local flag. Phase 14 posts the draft to the backend,
 * which is the only thing that can actually issue the grant and the
 * activation token.
 *
 * The three steps live under one route so the draft survives moving between
 * them. A step is addressable (`/restaurants/onboard/2`) but the draft is
 * component state, so a hard reload restarts the wizard — acceptable while
 * there is no server to persist a partial record to.
 */
export default function OnboardingWizard({
  status = SAMPLE_NETWORK_STATUS,
}: {
  status?: NetworkStatus;
}) {
  const navigate = useNavigate();
  const { step } = useParams();

  const [draft, setDraft] = useState<OnboardingDraft>(EMPTY_DRAFT);
  const [simulateConflict, setSimulateConflict] = useState(false);
  const [grantState, setGrantState] = useState<GrantState>('review');
  const [resendNotice, setResendNotice] = useState<string | null>(null);

  const current = clampStep(step);

  function go(next: number) {
    navigate(`/restaurants/onboard/${next}`);
  }

  function patch(changes: Partial<OnboardingDraft>) {
    setDraft((previous) => ({ ...previous, ...changes }));
  }

  function reset() {
    setDraft(EMPTY_DRAFT);
    setSimulateConflict(false);
    setGrantState('review');
    setResendNotice(null);
    go(1);
  }

  const subtitle =
    current === 1
      ? 'Restaurant details'
      : current === 2
        ? 'Access details'
        : 'Review & grant access';

  return (
    <ConsoleLayout
      title="Onboard Restaurant"
      subtitle={subtitle}
      statusStrip={
        <ConsoleStatusStrip
          activeRescues={status.activeRescues}
          needIntervention={status.needIntervention}
          pickupsApproaching={status.pickupsApproaching}
          version={status.consoleVersion}
        />
      }
    >
      <nav className="crumbs t-body-sm" aria-label="Breadcrumb">
        <span className="muted">Management</span>
        <span aria-hidden="true">/</span>
        <Link to="/overview">Restaurants</Link>
        <span aria-hidden="true">/</span>
        <span className="muted">Onboard Restaurant</span>
      </nav>

      <section className="intro">
        <div>
          <h1 className="t-headline-lg">
            {current === 3 ? 'Review & Grant Access' : 'Onboard Restaurant'}
          </h1>
          <p className="t-body-md">
            {current === 1 &&
              'Create a restaurant partner profile and initialize their FoodLoop rescue protocol.'}
            {current === 2 &&
              'Set up secure dashboard access for the restaurant partner.'}
            {current === 3 &&
              'Review the restaurant information before creating dashboard access.'}
          </p>
        </div>

        <div className="intro__actions">
          <span className="pill t-label-sm">
            {ONBOARDING_CONFIG.operatorDesk} · {ONBOARDING_CONFIG.operatorName}
          </span>
          <span className="pill t-label-sm">
            <span className="icon" style={{ fontSize: 15 }} aria-hidden="true">
              verified_user
            </span>
            Restricted Operator Provisioning
          </span>
        </div>
      </section>

      <div className="alertcard alertcard--neutral t-body-sm" style={{ margin: 0 }}>
        <span className="icon" style={{ fontSize: 18 }} aria-hidden="true">
          science
        </span>
        <div>
          <strong>Nothing is provisioned yet.</strong> Granting access here
          does not create an account or send an email — the backend that issues
          the partner grant and activation token arrives in Phase 14.
        </div>
      </div>

      {current === 1 && (
        <StepDetails
          draft={draft}
          onChange={patch}
          onCancel={() => navigate('/overview')}
          onNext={() => go(2)}
        />
      )}

      {current === 2 && (
        <StepAccess
          draft={draft}
          onChange={patch}
          simulateConflict={simulateConflict}
          onSimulateConflict={setSimulateConflict}
          onBack={() => go(1)}
          onNext={() => go(3)}
        />
      )}

      {current === 3 && (
        <StepReview
          draft={draft}
          state={grantState}
          onBack={() => go(2)}
          onEditDetails={() => go(1)}
          onEditAccess={() => {
            setGrantState('review');
            go(2);
          }}
          // A collision staged at step 2 surfaces here as the design's 409,
          // rather than the grant appearing to succeed.
          onGrant={() =>
            setGrantState(simulateConflict ? 'conflict' : 'granted')
          }
          onOnboardAnother={reset}
          onResend={() =>
            setResendNotice(
              'No email was re-sent — dispatching activation tokens needs the ' +
                'Phase 14 provisioning service.',
            )
          }
          resendNotice={resendNotice}
        />
      )}
    </ConsoleLayout>
  );
}

/** Keeps a hand-typed step in range. */
function clampStep(raw: string | undefined): number {
  const parsed = Number.parseInt(raw ?? '1', 10);
  if (Number.isNaN(parsed)) return 1;
  return Math.min(3, Math.max(1, parsed));
}
