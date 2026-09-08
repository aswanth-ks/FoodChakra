import { Navigate, Route, Routes } from 'react-router-dom';
import RequireAuth from './features/auth/RequireAuth';
import LoginPage from './features/auth/LoginPage';
import OverviewPage from './features/overview/OverviewPage';
import LiveRescueMapPage from './features/rescues/LiveRescueMapPage';
import RescueDetailPage from './features/rescues/RescueDetailPage';
import CoveragePage from './features/rescues/CoveragePage';
import RescueQueuePage from './features/rescues/RescueQueuePage';
import EscalationPage from './features/rescues/EscalationPage';
import AnalyticsPage from './features/analytics/AnalyticsPage';
import OnboardingWizard from './features/restaurants/OnboardingWizard';
import RestaurantsPage from './features/restaurants/RestaurantsPage';
import HealthPage from './features/health/HealthPage';

/**
 * Operations Console routes.
 *
 * Overview, Live Rescues (with the rescue detail and coverage views), Rescue
 * Queue, Escalations and Analytics are built. The remaining console
 * destinations appear in the sidebar as disabled rows rather than routes to
 * empty pages, so the nav shows the shape of the console without pretending
 * those screens exist.
 */
export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/overview"
        element={
          <RequireAuth>
            <OverviewPage />
          </RequireAuth>
        }
      />
      <Route
        path="/live-rescues"
        element={
          <RequireAuth>
            <LiveRescueMapPage />
          </RequireAuth>
        }
      />
      <Route
        path="/live-rescues/:id"
        element={
          <RequireAuth>
            <RescueDetailPage />
          </RequireAuth>
        }
      />
      <Route
        path="/live-rescues/:id/coverage"
        element={
          <RequireAuth>
            <CoveragePage />
          </RequireAuth>
        }
      />
      <Route
        path="/rescue-queue"
        element={
          <RequireAuth>
            <RescueQueuePage />
          </RequireAuth>
        }
      />
      <Route
        path="/escalations"
        element={
          <RequireAuth>
            <EscalationPage />
          </RequireAuth>
        }
      />
      <Route
        path="/analytics"
        element={
          <RequireAuth>
            <AnalyticsPage />
          </RequireAuth>
        }
      />
      <Route
        path="/restaurants"
        element={
          <RequireAuth>
            <RestaurantsPage />
          </RequireAuth>
        }
      />
      {/* The three onboarding steps share one route so the draft survives
          moving between them. */}
      <Route
        path="/restaurants/onboard"
        element={<Navigate to="/restaurants/onboard/1" replace />}
      />
      <Route
        path="/restaurants/onboard/:step"
        element={
          <RequireAuth>
            <OnboardingWizard />
          </RequireAuth>
        }
      />
      {/* Phase 0 backend connectivity check, kept reachable for diagnostics. */}
      <Route path="/health" element={<HealthPage />} />
      <Route path="*" element={<Navigate to="/overview" replace />} />
    </Routes>
  );
}
