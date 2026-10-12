import crypto from 'crypto';
import { config } from '../config';

export interface SsoPayload {
  timestamp: number;
  nonce: string;
  staff_id: number;
  school_slug: string;
  role: number;
  operator: string;
  purpose: string;
}

export interface SsoGrantOptions {
  schoolDomain: string;
  schoolSlug: string;
  staffId: number;
  operator: string;
  purpose?: string;
  role?: number;
}

export class SsoService {
  /**
   * Generates a short-lived, tenant-bound, single-use cryptographic grant for
   * an authenticated master operator to access a specific school staff account.
   */
  public static generateToken(options: Omit<SsoGrantOptions, 'schoolDomain'>): string {
    const payload: SsoPayload = {
      timestamp: Math.floor(Date.now() / 1000),
      nonce: crypto.randomBytes(16).toString('hex'),
      staff_id: options.staffId,
      school_slug: options.schoolSlug,
      role: options.role ?? 7, // Super Admin
      operator: options.operator,
      purpose: options.purpose || 'school_access',
    };

    const payloadJson = JSON.stringify(payload);
    const payloadB64 = Buffer.from(payloadJson).toString('base64');

    const signature = crypto
      .createHmac('sha256', config.masterSsoSecret)
      .update(payloadB64)
      .digest('hex');

    return `${payloadB64}.${signature}`;
  }

  /**
   * Constructs the full SSO redirect URL for a school.
   */
  public static getSsoRedirectUrl(options: SsoGrantOptions): string {
    const { schoolDomain, ...grant } = options;
    const token = this.generateToken(grant);
    const protocol = schoolDomain.includes('localhost') ? 'http' : 'https';
    return `${protocol}://${schoolDomain}/site/sso_login?token=${encodeURIComponent(token)}`;
  }
}
