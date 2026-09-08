/** Domain types behind the three restaurant onboarding steps. */

/** The categories a partner can be filed under. */
export const RESTAURANT_CATEGORIES = [
  'Restaurant (Sit-down / Fine dining)',
  'Café / Bakery',
  'Commercial Catering',
  'Hotel / Hospitality Kitchen',
  'Institutional / University Dining',
  'Other Food Producer',
] as const;

export type RestaurantCategory = (typeof RESTAURANT_CATEGORIES)[number];

/**
 * The partner record being assembled across the three steps.
 *
 * Note what is *not* here: there is no password field, and there never
 * should be. The design's "zero-password architecture" means desk operators
 * stage an email and a role, and the partner sets their own credentials from
 * the activation link. An operator must never be able to see or set a
 * partner's password.
 */
export interface OnboardingDraft {
  businessName: string;
  branchName: string;
  category: RestaurantCategory;
  operatingArea: string;
  /** Optional, but the design marks it "highly recommended". */
  pickupLocation: string;

  contactName: string;
  /** "General Manager". */
  contactRole: string;
  phone: string;

  /** The address the activation link is sent to. */
  loginEmail: string;
}

export const EMPTY_DRAFT: OnboardingDraft = {
  businessName: '',
  branchName: '',
  category: RESTAURANT_CATEGORIES[0],
  operatingArea: '',
  pickupLocation: '',
  contactName: '',
  contactRole: '',
  phone: '',
  loginEmail: '',
};

/** A fixed baseline parameter shown on step 1. */
export interface BaselineParameter {
  label: string;
  value: string;
  caption: string;
  icon: string;
}

/** One stage of the credential lifecycle diagram on step 2. */
export interface LifecycleStage {
  index: number;
  tag: string;
  title: string;
  body: string;
}

/** Static copy and options the three steps share. */
export interface OnboardingConfig {
  entityId: string;
  dispatchHub: string;
  operatorDesk: string;
  operatorName: string;

  baseline: BaselineParameter[];
  baselineNote: string;

  roleTitle: string;
  roleCaption: string;
  roleConsole: string;
  capabilities: string[];
  roleNote: string;

  zeroPasswordTitle: string;
  zeroPasswordLead: string;
  zeroPasswordBody: string;
  lifecycle: LifecycleStage[];

  /** The account the conflict simulation collides with. */
  conflictAccountId: string;
  conflictNodeName: string;
  conflictSuggestions: string[];
}

/** Whether step 1 is answerable. */
export function detailsComplete(draft: OnboardingDraft): boolean {
  return (
    draft.businessName.trim() !== '' &&
    draft.branchName.trim() !== '' &&
    draft.operatingArea.trim() !== '' &&
    draft.contactName.trim() !== '' &&
    draft.phone.trim() !== ''
  );
}

/** A deliberately permissive check: this only gates the wizard, not auth. */
export function isEmailValid(email: string): boolean {
  const trimmed = email.trim();
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(trimmed);
}

/** The domain half of the login email, for the registry check copy. */
export function emailDomain(email: string): string {
  const at = email.lastIndexOf('@');
  return at === -1 ? '' : email.slice(at + 1).toLowerCase();
}
