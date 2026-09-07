import { apiFetch } from './client';

export interface HealthResponse {
  status: 'ok' | 'degraded';
  app: string;
  environment: string;
  database: { connected: boolean; version: string | null; error: string | null };
}

export const fetchHealth = () => apiFetch<HealthResponse>('/health');
