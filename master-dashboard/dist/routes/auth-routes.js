"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireAuth = requireAuth;
const express_1 = require("express");
const config_1 = require("../config");
const router = (0, express_1.Router)();
const MAX_FAILED_ATTEMPTS = 5;
const ATTEMPT_WINDOW_MS = 15 * 60 * 1000;
const LOCKOUT_MS = 15 * 60 * 1000;
const loginThrottle = new Map();
function throttleKey(req) {
    const ip = req.ip || req.socket.remoteAddress || 'unknown';
    const username = (req.body?.username || '').toString().toLowerCase();
    return `${ip}|${username}`;
}
function isBlocked(key) {
    const rec = loginThrottle.get(key);
    if (!rec)
        return false;
    if (rec.blockedUntil > Date.now())
        return true;
    if (Date.now() - rec.firstAttemptAt > ATTEMPT_WINDOW_MS) {
        loginThrottle.delete(key);
    }
    return false;
}
function recordFailure(key) {
    const now = Date.now();
    const rec = loginThrottle.get(key);
    if (!rec || now - rec.firstAttemptAt > ATTEMPT_WINDOW_MS) {
        loginThrottle.set(key, { attempts: 1, firstAttemptAt: now, blockedUntil: 0 });
        return;
    }
    rec.attempts += 1;
    if (rec.attempts >= MAX_FAILED_ATTEMPTS) {
        rec.blockedUntil = now + LOCKOUT_MS;
        rec.attempts = 0;
    }
}
function clearFailures(key) {
    loginThrottle.delete(key);
}
function requireAuth(req, res, next) {
    if (req.session?.isAuthenticated) {
        return next();
    }
    return res.redirect('/auth/login');
}
router.get('/login', (req, res) => {
    if (req.session?.isAuthenticated) {
        return res.redirect('/');
    }
    res.render('login', { error: null });
});
router.post('/login', (req, res) => {
    const key = throttleKey(req);
    if (isBlocked(key)) {
        return res.status(429).render('login', {
            error: 'Too many failed login attempts. Please try again later.',
        });
    }
    const { username, password } = req.body;
    if (username === config_1.config.masterAdminUsername && password === config_1.config.masterAdminPassword) {
        clearFailures(key);
        req.session.regenerate((err) => {
            if (err) {
                console.error('[Auth] Session regeneration failed:', err);
                return res.render('login', {
                    error: 'Unable to start a session. Please try again.',
                });
            }
            req.session.isAuthenticated = true;
            req.session.user = { username, role: 'Network Super Admin' };
            return res.redirect('/');
        });
        return;
    }
    recordFailure(key);
    return res.render('login', { error: 'Invalid master credentials. Please try again.' });
});
router.get('/logout', (req, res) => {
    req.session.destroy(() => {
        res.redirect('/auth/login');
    });
});
exports.default = router;
