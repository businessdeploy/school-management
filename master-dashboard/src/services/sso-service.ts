import crypto from 'crypto';
import { config } from '../config';

export interface SsoPayload {
  timestamp: number;
  nonce: string;
  staff_id: number;
  school_slug: string;
  role: number;
}

export class SsoService {
  /**
   * Generates a secure, short-lived (120s) cryptographic token for direct Super Admin login.
   */
  public static generateToken(schoolSlug: string, staffId: number = 1): string {
    const payload: SsoPayload = {
      timestamp: Math.floor(Date.now() / 1000),
      nonce: crypto.randomBytes(16).toString('hex'),
      staff_id: staffId,
      school_slug: schoolSlug,
      role: 7, // Super Admin
    };

    const payloadJson = JSON.stringify(payload);
    const payloadB64 = Buffer.from(payloadJson).toString('base64');
    
    // Sign with HMAC-SHA256
    const signature = crypto
      .createHmac('sha256', config.masterSsoSecret)
      .update(payloadB64)
      .digest('hex');

    return `${payloadB64}.${signature}`;
  }

  /**
   * Constructs the full SSO redirect URL for a school.
   */
  public static getSsoRedirectUrl(schoolDomain: string, schoolSlug: string, staffId: number = 1): string {
    const token = this.generateToken(schoolSlug, staffId);
    const protocol = schoolDomain.includes('localhost') ? 'http' : 'https';
    return `${protocol}://${schoolDomain}/site/sso_login?token=${encodeURIComponent(token)}`;
  }
}
