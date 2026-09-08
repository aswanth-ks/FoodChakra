import { Navigate, Route, Routes } from 'react-router-dom';
import RequireAuth from './features/auth/RequireAuth';
import LoginPage from './features/auth/LoginPage';
import OverviewPage from './features/overview/OverviewPage';
import LiveRescueMapPage from './features/rescues/LiveRescueMapPage';
import RescueDetailPage from './features/rescues/RescueDetailPage';
import HealthPage from './features/health/HealthPage';

/**
 * Operations Console routes.
 *
 * Overview, Live Rescues and the rescue detail view are built. The other
 * console destinations appear in the sidebar as disabled rows rather than
 * routes to empty pages, so the nav shows the shape of the console without
 * pretending those screens exist.
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
      {/* Phase 0 backend connectivity check, kept reachable for diagnostics. */}
      <Route path="/health" element={<HealthPage />} />
      <Route path="*" element={<Navigate to="/overview" replace />} />
    </Routes>
  );
}
