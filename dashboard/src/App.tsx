import { useQuery } from '@tanstack/react-query';
import { API_URL } from './lib/api/client';
import { fetchHealth } from './lib/api/health';

/**
 * Phase 0 connectivity proof for the Operations Dashboard.
 * Replaced by the real ops shell in Phase 14.
 */
export default function App() {
  const { data, isPending, error, refetch } = useQuery({
    queryKey: ['health'],
    queryFn: fetchHealth,
    retry: false,
  });

  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', padding: 32, maxWidth: 640 }}>
      <h1 style={{ marginBottom: 4 }}>FoodLoop — Operations Dashboard</h1>
      <p style={{ color: '#5c625c', marginTop: 0 }}>Phase 0 · backend connectivity check</p>

      {isPending && <p>Contacting the backend…</p>}

      {error && (
        <div style={{ border: '1px solid #f5c2c2', background: '#fdf2f2', padding: 16, borderRadius: 12 }}>
          <strong>Something went wrong</strong>
          <p style={{ margin: '8px 0 12px' }}>{(error as Error).message}</p>
          <button onClick={() => void refetch()}>Try again</button>
        </div>
      )}

      {data && (
        <dl style={{ border: '1px solid #e0e4e0', padding: 16, borderRadius: 12, background: '#fff' }}>
          <Row label="Status" value={data.status} />
          <Row label="Environment" value={data.environment} />
          <Row label="MongoDB" value={data.database.connected ? (data.database.version ?? 'connected') : 'not connected'} />
          <Row label="Endpoint" value={API_URL} />
        </dl>
      )}
    </main>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: 'flex', gap: 12, padding: '4px 0' }}>
      <dt style={{ width: 120, color: '#5c625c' }}>{label}</dt>
      <dd style={{ margin: 0, fontWeight: 500 }}>{value}</dd>
    </div>
  );
}
