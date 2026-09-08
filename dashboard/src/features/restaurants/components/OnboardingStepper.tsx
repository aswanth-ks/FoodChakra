const STEPS = [
  {
    index: 1,
    title: 'Restaurant Details',
    caption: 'Basic profile & operations',
  },
  {
    index: 2,
    title: 'Dashboard Access',
    caption: 'Authorized email invitation',
  },
  {
    index: 3,
    title: 'Review & Provision',
    caption: 'Verification & link dispatch',
  },
];

/** The three-step header shared by every onboarding step. */
export default function OnboardingStepper({ current }: { current: number }) {
  return (
    <ol className="wizard" aria-label="Onboarding progress">
      {STEPS.map((step, index) => {
        const done = step.index < current;
        const active = step.index === current;
        const state = done ? 'done' : active ? 'active' : 'idle';

        return (
          <li className={`wizard__step wizard__step--${state}`} key={step.index}>
            <span className="wizard__marker">
              {done ? (
                <span className="icon" style={{ fontSize: 16 }}>
                  check
                </span>
              ) : (
                step.index
              )}
            </span>
            <span className="wizard__body">
              <span className="t-label-sm upper wizard__tag">
                Step {step.index} •{' '}
                {done ? 'Completed' : active ? 'Active' : 'Pending'}
              </span>
              <span className="t-body-md" style={{ fontWeight: 600 }}>
                {step.title}
              </span>
              <span className="t-body-sm muted">{step.caption}</span>
            </span>
            {index < STEPS.length - 1 && (
              <span className="wizard__arrow icon" aria-hidden="true">
                arrow_forward
              </span>
            )}
          </li>
        );
      })}
    </ol>
  );
}
