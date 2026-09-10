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
import RescuersPage from './features/rescuers/RescuersPage';
import LocationsPage from './features/locations/LocationsPage';
import ActivityLogPage from './features/activity/ActivityLogPage';
import SettingsPage from './features/settings/SettingsPage';
import ZeroWasteOverviewPage from './features/zerowaste/ZeroWasteOverviewPage';
import FallbackOpportunityPage from './features/zerowaste/FallbackOpportunityPage';
import RecoveryPartnersPage from './features/zerowaste/RecoveryPartnersPage';
import RoutingPage from './features/zerowaste/RoutingPage';
import RecoveryHistoryPage from './features/zerowaste/RecoveryHistoryPage';
import { mostUrgentCaseId } from './features/zerowaste/data/sampleZeroWaste';
import HealthPage from './features/health/HealthPage';

/**
 * Operations Console routes.
 *
 * Overview, Live Rescues (with the rescue detail and coverage views), Rescue
 * Queue, Escalations, Analytics and the Zero-Waste Network (its overview,
 * recovery partners, routing policy and per-case fallback view) cover
 * Operations Core; Restaurants, Onboard Restaurant, Rescuers, Locations and
 * Activity cover Management, with Settings in the sidebar footer. Every
 * console destination now has a route.
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
      <Route
        path="/rescuers"
        element={
          <RequireAuth>
            <RescuersPage />
          </RequireAuth>
        }
      />
      <Route
        path="/locations"
        element={
          <RequireAuth>
            <LocationsPage />
          </RequireAuth>
        }
      />
      <Route
        path="/activity"
        element={
          <RequireAuth>
            <ActivityLogPage />
          </RequireAuth>
        }
      />
      <Route
        path="/settings"
        element={
          <RequireAuth>
            <SettingsPage />
          </RequireAuth>
        }
      />
      {/* The Zero-Waste Network: the fallback tier, once the human tier has
          failed. Fallback Opportunity is a per-case detail view, opened from
          the overview the way rescue detail is opened from Live Rescues. */}
      <Route
        path="/zero-waste"
        element={
          <RequireAuth>
            <ZeroWasteOverviewPage />
          </RequireAuth>
        }
      />
      {/* The sidebar entry needs a concrete case. It opens whichever open case
          has the least time left - the same one the overview ranks first.
          Phase 14 resolves this from the API instead of the fixture. */}
      <Route
        path="/zero-waste/fallback"
        element={<FallbackIndexRedirect />}
      />
      <Route
        path="/zero-waste/fallback/:id"
        element={
          <RequireAuth>
            <FallbackOpportunityPage />
          </RequireAuth>
        }
      />
      <Route
        path="/zero-waste/partners"
        element={
          <RequireAuth>
            <RecoveryPartnersPage />
          </RequireAuth>
        }
      />
      <Route
        path="/zero-waste/routing"
        element={
          <RequireAuth>
            <RoutingPage />
          </RequireAuth>
        }
      />
      <Route
        path="/zero-waste/history"
        element={
          <RequireAuth>
            <RecoveryHistoryPage />
          </RequireAuth>
        }
      />
      {/* Phase 0 backend connectivity check, kept reachable for diagnostics. */}
      <Route path="/health" element={<HealthPage />} />
      <Route path="*" element={<Navigate to="/overview" replace />} />
    </Routes>
  );
}

/**
 * Sends the sidebar's Fallback Opportunity entry to the most urgent open case.
 *
 * With no open cases there is nothing to show, so it falls back to the
 * Zero-Waste overview rather than rendering a case page with no case.
 */
function FallbackIndexRedirect() {
  const id = mostUrgentCaseId();
  return (
    <Navigate to={id ? `/zero-waste/fallback/${id}` : '/zero-waste'} replace />
  );
}
