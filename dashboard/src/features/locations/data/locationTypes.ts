/** Domain types behind Locations Management. */

/**
 * Operational state of a zone.
 *
 * `live` is normal service. `strained` means demand is outrunning the
 * rescuers in the zone. `expanded` means the dynamic coverage radius is
 * currently widened past its standard band. `paused` means no new rescues are
 * dispatched there at all.
 */
export type ZoneStatus = 'live' | 'strained' | 'expanded' | 'paused';

export const ZONE_STATUS_LABEL: Record<ZoneStatus, string> = {
  live: 'Live',
  strained: 'Strained',
  expanded: 'Expanded',
  paused: 'Paused',
};

/** One row in the zone table. */
export interface ZoneRow {
  id: string;
  name: string;
  /** "EU-WEST / Sector 3". */
  sector: string;
  status: ZoneStatus;
  partners: number;
  rescuers: number;
  activeRescues: number;
  /** Standard dispatch radius, e.g. "2.5 km". */
  standardRadius: string;
  /** Radius actually in force right now - differs when coverage is expanded. */
  currentRadius: string;
  /** Share of rescues matched inside the standard band, e.g. "94.2%". */
  coverage: string;
  /** "12 min". */
  avgDispatch: string;
}

/** One pickup point registered inside a zone. */
export interface PickupPoint {
  name: string;
  kind: string;
  /** "Open 06:00-22:00". */
  hours: string;
  active: boolean;
}

/** One entry in the zone's coverage history. */
export interface ZoneEvent {
  when: string;
  title: string;
  detail: string;
}

/** The right-hand detail panel for the selected zone. */
export interface ZoneDetail {
  id: string;
  /** Free-text summary of why the zone is in its current state. */
  summary: string;
  /** Population served, as shown. */
  population: string;
  /** "18.4 km2". */
  area: string;
  peakWindow: string;
  unmatchedRate: string;
  pickupPoints: PickupPoint[];
  events: ZoneEvent[];
}

/** Everything the Locations page renders. */
export interface LocationDirectory {
  totals: {
    all: number;
    live: number;
    strained: number;
    expanded: number;
    paused: number;
  };
  sectors: string[];
  rows: ZoneRow[];
  details: Record<string, ZoneDetail>;
}
