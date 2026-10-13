"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.csrfProtection = csrfProtection;
const crypto_1 = __importDefault(require("crypto"));
const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);
function getCsrfSecret(req) {
    const session = req.session;
    if (!session.csrfSecret) {
        session.csrfSecret = crypto_1.default.randomBytes(32).toString('hex');
    }
    return session.csrfSecret;
}
/**
 * Synchronizer-token CSRF protection for authenticated mutations.
 * Exposes the token to views via `res.locals.csrfToken` and rejects any
 * state-changing request whose `_csrf` field (or `X-CSRF-Token` header)
 * does not match the per-session secret.
 */
function csrfProtection(req, res, next) {
    const secret = getCsrfSecret(req);
    res.locals.csrfToken = secret;
    if (SAFE_METHODS.has((req.method || '').toUpperCase())) {
        return next();
    }
    const token = (req.body && (req.body._csrf || req.body.csrf)) || req.get('x-csrf-token');
    if (typeof token !== 'string' || token.length === 0) {
        return res.status(403).send('Invalid or missing CSRF token.');
    }
    const expected = Buffer.from(secret);
    const provided = Buffer.from(token);
    if (provided.length !== expected.length || !crypto_1.default.timingSafeEqual(provided, expected)) {
        return res.status(403).send('Invalid or missing CSRF token.');
    }
    return next();
}
