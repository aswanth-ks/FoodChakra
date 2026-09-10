import {
  TIER_LABEL,
  TIER_SHORT,
  type RecoveryTier,
} from '../data/zeroWasteTypes';
import { TIER_BG, TIER_COLOR, TIER_ICON } from '../data/tierStyle';

/** A tier as a chip. `short` uses the compact label for table cells. */
export function TierChip({
  tier,
  short = false,
}: {
  tier: RecoveryTier;
  short?: boolean;
}) {
  return (
    <span
      className="chip t-label-sm"
      style={{ background: TIER_BG[tier], color: TIER_COLOR[tier] }}
    >
      <span className="icon" style={{ fontSize: 13 }} aria-hidden="true">
        {TIER_ICON[tier]}
      </span>
      {short ? TIER_SHORT[tier] : TIER_LABEL[tier]}
    </span>
  );
}
