"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SsoService = void 0;
const crypto_1 = __importDefault(require("crypto"));
const config_1 = require("../config");
class SsoService {
    /**
     * Generates a short-lived, tenant-bound, single-use cryptographic grant for
     * an authenticated master operator to access a specific school staff account.
     */
    static generateToken(options) {
        const payload = {
            timestamp: Math.floor(Date.now() / 1000),
            nonce: crypto_1.default.randomBytes(16).toString('hex'),
            staff_id: options.staffId,
            school_slug: options.schoolSlug,
            role: options.role ?? 7, // Super Admin
            operator: options.operator,
            purpose: options.purpose || 'school_access',
        };
        const payloadJson = JSON.stringify(payload);
        const payloadB64 = Buffer.from(payloadJson).toString('base64');
        const signature = crypto_1.default
            .createHmac('sha256', config_1.config.masterSsoSecret)
            .update(payloadB64)
            .digest('hex');
        return `${payloadB64}.${signature}`;
    }
    /**
     * Constructs the full SSO redirect URL for a school.
     */
    static getSsoRedirectUrl(options) {
        const { schoolDomain, ...grant } = options;
        const token = this.generateToken(grant);
        const protocol = schoolDomain.includes('localhost') ? 'http' : 'https';
        return `${protocol}://${schoolDomain}/site/sso_login?token=${encodeURIComponent(token)}`;
    }
}
exports.SsoService = SsoService;
