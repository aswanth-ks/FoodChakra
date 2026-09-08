import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { readSession } from './session';

/**
 * Sends signed-out visitors to the login screen.
 *
 * A client-side guard only decides what renders — it is not a security
 * boundary, and never can be. Phase 3's console API must reject every request
 * that arrives without a valid ops session, regardless of what this component
 * allows on screen.
 */
export default function RequireAuth({ children }: { children: ReactNode }) {
  const location = useLocation();
  const session = readSession();

  if (!session) {
    // `state` lets the login screen send the operator back where they were
    // headed once the real sign-in exists.
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }

  return <>{children}</>;
}
