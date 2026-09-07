"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireAuth = requireAuth;
const express_1 = require("express");
const config_1 = require("../config");
const router = (0, express_1.Router)();
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
    const { username, password } = req.body;
    if (username === config_1.config.masterAdminUsername && password === config_1.config.masterAdminPassword) {
        req.session.isAuthenticated = true;
        req.session.user = { username, role: 'Network Super Admin' };
        return res.redirect('/');
    }
    return res.render('login', { error: 'Invalid master credentials. Please try again.' });
});
router.get('/logout', (req, res) => {
    req.session.destroy(() => {
        res.redirect('/auth/login');
    });
});
exports.default = router;
