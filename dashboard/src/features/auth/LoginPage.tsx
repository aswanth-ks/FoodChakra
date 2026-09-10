import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { isOpsEmail, sessionForEmail, writeSession } from './session';
import { readPreferences } from '../settings/data/preferences';

/**
 * Operations Console sign-in.
 *
 * There is no Stitch design for this screen — the console designs start at
 * Overview — so it is built from the console's own design tokens rather than
 * invented separately: same palette, same type scale, same card treatment.
 *
 * Nothing is authenticated here. See `session.ts` for what Phase 3 replaces.
 */
export default function LoginPage() {
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [touched, setTouched] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const emailInvalid = touched && email.trim().length > 0 && !isOpsEmail(email);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setTouched(true);
    setError(null);

    if (email.trim().length === 0 || password.length === 0) {
      setError('Enter your console email and password.');
      return;
    }

    if (!isOpsEmail(email)) {
      setError('Console access is limited to FoodLoop operations accounts.');
      return;
    }

    setSubmitting(true);
    writeSession(sessionForEmail(email));
    // The operator's chosen landing page, from console preferences.
    navigate(readPreferences().landing, { replace: true });
  }

  return (
    <div className="login">
      <aside className="login__aside">
        <div className="login__brandrow">
          <div className="sidebar__brand">
            <div className="sidebar__mark" aria-hidden="true">
              FL
            </div>
            <div>
              <div className="t-headline-sm">FoodLoop</div>
              <div className="t-label-sm" style={{ opacity: 0.7 }}>
                Operations Console
              </div>
            </div>
          </div>
        </div>

        <div>
          <h2 className="t-headline-xl">Keep every rescue moving.</h2>
          <p className="t-body-lg">
            Live visibility across the rescue network — what is in flight, what
            is running out of time, and what needs a human right now.
          </p>
        </div>

        <div className="login__stats">
          <div className="login__stat">
            <span className="t-metric" style={{ fontSize: 24 }}>
              42
            </span>
            <span className="t-label-sm" style={{ opacity: 0.7 }}>
              ACTIVE RESCUES
            </span>
          </div>
          <div className="login__stat">
            <span className="t-metric" style={{ fontSize: 24 }}>
              94%
            </span>
            <span className="t-label-sm" style={{ opacity: 0.7 }}>
              SUCCESS RATE
            </span>
          </div>
          <div className="login__stat">
            <span className="t-metric" style={{ fontSize: 24 }}>
              11m
            </span>
            <span className="t-label-sm" style={{ opacity: 0.7 }}>
              AVG MATCH
            </span>
          </div>
        </div>
      </aside>

      <main className="login__panel">
        <form className="login__form" onSubmit={handleSubmit} noValidate>
          <div className="t-label-sm upper muted">Restricted access</div>
          <h1 className="t-headline-lg">Sign in to the console</h1>
          <p className="t-body-md muted" style={{ margin: '4px 0 0' }}>
            Operations staff only. Accounts are issued by FoodLoop.
          </p>

          <div className={`field${emailInvalid ? ' field--invalid' : ''}`}>
            <label className="t-label-md" htmlFor="console-email">
              Work email
            </label>
            <input
              id="console-email"
              type="email"
              autoComplete="username"
              placeholder="name@foodloop.com"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              onBlur={() => setTouched(true)}
              aria-invalid={emailInvalid}
              aria-describedby={emailInvalid ? 'console-email-error' : undefined}
            />
            {emailInvalid && (
              <span
                className="t-body-sm field__error"
                id="console-email-error"
                role="alert"
              >
                Use your @foodloop.com operations address.
              </span>
            )}
          </div>

          <div className="field">
            <label className="t-label-md" htmlFor="console-password">
              Password
            </label>
            <input
              id="console-password"
              type="password"
              autoComplete="current-password"
              placeholder="••••••••"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
          </div>

          {error && (
            <div className="login__alert t-body-sm" role="alert">
              <span className="icon" style={{ fontSize: 16 }}>
                error
              </span>
              <span>{error}</span>
            </div>
          )}

          <button
            className="btn btn--primary btn--block"
            type="submit"
            disabled={submitting}
            style={{ marginTop: 22 }}
          >
            {submitting ? 'Signing in…' : 'Sign in'}
          </button>

          <p className="login__note t-body-sm">
            <strong>Not real authentication yet.</strong> No password is
            checked and no session is issued — any{' '}
            <code>@foodloop.com</code> address opens the console. The backend
            login lands in Phase 3.
          </p>
        </form>
      </main>
    </div>
  );
}
