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
     * Generates a secure, short-lived (120s) cryptographic token for direct Super Admin login.
     */
    static generateToken(schoolSlug, staffId = 1) {
        const payload = {
            timestamp: Math.floor(Date.now() / 1000),
            nonce: crypto_1.default.randomBytes(16).toString('hex'),
            staff_id: staffId,
            school_slug: schoolSlug,
            role: 7, // Super Admin
        };
        const payloadJson = JSON.stringify(payload);
        const payloadB64 = Buffer.from(payloadJson).toString('base64');
        // Sign with HMAC-SHA256
        const signature = crypto_1.default
            .createHmac('sha256', config_1.config.masterSsoSecret)
            .update(payloadB64)
            .digest('hex');
        return `${payloadB64}.${signature}`;
    }
    /**
     * Constructs the full SSO redirect URL for a school.
     */
    static getSsoRedirectUrl(schoolDomain, schoolSlug, staffId = 1) {
        const token = this.generateToken(schoolSlug, staffId);
        const protocol = schoolDomain.includes('localhost') ? 'http' : 'https';
        return `${protocol}://${schoolDomain}/site/sso_login?token=${encodeURIComponent(token)}`;
    }
}
exports.SsoService = SsoService;
