export interface FieldValidation {
  valid: boolean;
  error?: string;
  value?: any;
}

const RESERVED_SLUGS = new Set([
  'www',
  'admin',
  'api',
  'auth',
  'master',
  'manage',
  'manage-school-crm',
  'localhost',
  'schools',
  'networks',
  'master-data',
  'app',
  'static',
  'assets',
  'login',
  'logout',
  'sso',
  'caddy',
  'health',
  'account',
  'accounts',
]);

export function normalizeSlug(input: string): string {
  return (input || '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9-]/g, '')
    .replace(/^-+|-+$/g, '');
}

export function validateSlug(input: string): FieldValidation {
  const slug = normalizeSlug(input);
  if (!slug) {
    return { valid: false, error: 'Slug is required and may only contain letters, numbers, and hyphens.' };
  }
  if (slug.length < 2) {
    return { valid: false, error: 'Slug must be at least 2 characters long.' };
  }
  if (slug.length > 40) {
    return { valid: false, error: 'Slug must be at most 40 characters long.' };
  }
  if (RESERVED_SLUGS.has(slug)) {
    return { valid: false, error: `Slug "${slug}" is reserved.` };
  }
  return { valid: true, value: slug };
}

export function normalizeDomain(input: string): string {
  return (input || '')
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\//, '')
    .replace(/\/+$/, '');
}

const HOSTNAME_RE = /^(?=.{1,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)*[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/;

export function validateDomain(input: string): FieldValidation {
  const domain = normalizeDomain(input);
  if (!domain) {
    return { valid: false, error: 'Domain is required.' };
  }
  if (!HOSTNAME_RE.test(domain)) {
    return { valid: false, error: `Domain "${domain}" is not a valid hostname.` };
  }
  return { valid: true, value: domain };
}

export function validateBoundedInt(input: any, min: number, max: number): FieldValidation {
  const raw = String(input ?? '').trim();
  if (!/^-?\d+$/.test(raw)) {
    return { valid: false, error: 'Value must be a whole number.' };
  }
  const n = parseInt(raw, 10);
  if (n < min || n > max) {
    return { valid: false, error: `Value must be between ${min} and ${max}.` };
  }
  return { valid: true, value: n };
}

export function isReservedSlug(slug: string): boolean {
  return RESERVED_SLUGS.has(normalizeSlug(slug));
}
