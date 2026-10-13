"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const master_db_1 = require("../db/master-db");
const permissions_1 = require("../permissions");
const totp_1 = require("../services/totp");
const router = (0, express_1.Router)();
router.get('/', async (req, res) => {
    const users = await master_db_1.MasterDb.listAdminUsers();
    res.render('users', {
        pageTitle: 'Users & Access',
        users,
        roles: permissions_1.ROLES,
        error: req.query.error || null,
        success: req.query.success || null,
    });
});
router.post('/create', async (req, res) => {
    const { username, password, displayName, role } = req.body;
    const cleanUsername = (username || '').trim();
    if (!cleanUsername) {
        return res.redirect('/users?error=' + encodeURIComponent('Username is required.'));
    }
    if (!password || String(password).length < 6) {
        return res.redirect('/users?error=' + encodeURIComponent('Password must be at least 6 characters.'));
    }
    if (!permissions_1.ROLES.includes(role)) {
        return res.redirect('/users?error=' + encodeURIComponent('Invalid role.'));
    }
    const existing = await master_db_1.MasterDb.getAdminUserByUsername(cleanUsername);
    if (existing) {
        return res.redirect('/users?error=' + encodeURIComponent(`Username "${cleanUsername}" is already taken.`));
    }
    try {
        await master_db_1.MasterDb.createAdminUser({
            username: cleanUsername,
            password: String(password),
            displayName: displayName ? String(displayName).trim() : undefined,
            role,
        });
        res.redirect('/users?success=' + encodeURIComponent(`User "${cleanUsername}" created.`));
    }
    catch (err) {
        console.error('[User Create Error]:', err);
        res.redirect('/users?error=' + encodeURIComponent('Failed to create user.'));
    }
});
router.post('/:id/toggle-active', async (req, res) => {
    const user = await master_db_1.MasterDb.getAdminUserById(req.params.id);
    if (!user)
        return res.redirect('/users');
    const currentUsername = req.session?.user?.username;
    if (user.username === currentUsername) {
        return res.redirect('/users?error=' + encodeURIComponent('You cannot deactivate your own account.'));
    }
    const nextActive = !user.isActive;
    if (!nextActive && user.role === 'superadmin') {
        const activeSuperadmins = (await master_db_1.MasterDb.listAdminUsers()).filter((u) => u.role === 'superadmin' && u.isActive);
        if (activeSuperadmins.length <= 1) {
            return res.redirect('/users?error=' + encodeURIComponent('Cannot deactivate the last active superadmin.'));
        }
    }
    await master_db_1.MasterDb.setAdminUserActive(user.id, nextActive);
    res.redirect('/users?success=' + encodeURIComponent(`User "${user.username}" ${nextActive ? 'activated' : 'deactivated'}.`));
});
router.get('/:id/mfa-setup', async (req, res) => {
    const user = await master_db_1.MasterDb.getAdminUserById(req.params.id);
    if (!user)
        return res.redirect('/users');
    const secret = (0, totp_1.generateTotpSecret)();
    req.session.pendingMfaSetup = { userId: user.id, secret };
    res.render('mfa-setup', {
        pageTitle: 'Setup MFA',
        user,
        secret,
        otpauthUrl: (0, totp_1.buildOtpauthUrl)('Prime School Fleet', user.username, secret),
        error: null,
    });
});
router.post('/:id/mfa-confirm', async (req, res) => {
    const user = await master_db_1.MasterDb.getAdminUserById(req.params.id);
    if (!user)
        return res.redirect('/users');
    const pending = req.session?.pendingMfaSetup;
    if (!pending || pending.userId !== user.id) {
        return res.redirect('/users?error=' + encodeURIComponent('MFA setup session expired. Please try again.'));
    }
    const { code } = req.body;
    if (!(0, totp_1.verifyTotp)(pending.secret, code)) {
        return res.render('mfa-setup', {
            pageTitle: 'Setup MFA',
            user,
            secret: pending.secret,
            otpauthUrl: (0, totp_1.buildOtpauthUrl)('Prime School Fleet', user.username, pending.secret),
            error: 'Invalid code. Please try again.',
        });
    }
    await master_db_1.MasterDb.setAdminUserMfaSecret(user.id, pending.secret);
    req.session.pendingMfaSetup = null;
    res.redirect('/users?success=' + encodeURIComponent(`MFA enabled for "${user.username}".`));
});
router.post('/:id/mfa-disable', async (req, res) => {
    const user = await master_db_1.MasterDb.getAdminUserById(req.params.id);
    if (!user)
        return res.redirect('/users');
    await master_db_1.MasterDb.setAdminUserMfaSecret(user.id, null);
    res.redirect('/users?success=' + encodeURIComponent(`MFA disabled for "${user.username}".`));
});
exports.default = router;
