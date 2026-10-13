"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const master_db_1 = require("../db/master-db");
const dns_service_1 = require("../services/dns-service");
const easypanel_service_1 = require("../services/easypanel-service");
const validation_1 = require("../validation");
const router = (0, express_1.Router)();
router.get('/', async (req, res) => {
    const networks = await master_db_1.MasterDb.getNetworks();
    const schools = await master_db_1.MasterDb.getSchools();
    res.render('networks', {
        pageTitle: 'Multi-Network & Custom Domain Routing',
        networks,
        schools,
        dnsResult: null,
        error: req.query.error || null,
        success: req.query.success || null,
    });
});
router.post('/create', async (req, res) => {
    const { name, rootDomain, description } = req.body;
    if (!name) {
        return res.redirect('/networks?error=' + encodeURIComponent('Network name is required.'));
    }
    const domainValidation = (0, validation_1.validateDomain)(rootDomain);
    if (!domainValidation.valid) {
        return res.redirect('/networks?error=' + encodeURIComponent(domainValidation.error || 'Invalid root domain.'));
    }
    const cleanRootDomain = domainValidation.value;
    const networks = await master_db_1.MasterDb.getNetworks();
    const existing = networks.find((n) => n.rootDomain.toLowerCase() === cleanRootDomain);
    if (existing) {
        return res.redirect('/networks?error=' + encodeURIComponent(`Root domain "${cleanRootDomain}" is already registered.`));
    }
    await master_db_1.MasterDb.addNetwork({
        name: name.trim(),
        rootDomain: cleanRootDomain,
        isDefault: false,
        description: description ? description.trim() : undefined,
    });
    res.redirect('/networks');
});
router.post('/verify-domain', async (req, res) => {
    const { domain, expectedTarget } = req.body;
    const networks = await master_db_1.MasterDb.getNetworks();
    const schools = await master_db_1.MasterDb.getSchools();
    const target = expectedTarget || 'ingress.yournetwork.com';
    const dnsResult = await dns_service_1.DnsService.verifyDomain(domain, target);
    res.render('networks', {
        pageTitle: 'Multi-Network & Custom Domain Routing',
        networks,
        schools,
        dnsResult,
    });
});
router.post('/bind-domain', async (req, res) => {
    const { schoolId, customDomain } = req.body;
    const school = await master_db_1.MasterDb.getSchoolById(schoolId);
    if (!school) {
        return res.redirect('/networks?error=' + encodeURIComponent('Selected school is invalid.'));
    }
    const domainValidation = (0, validation_1.validateDomain)(customDomain);
    if (!domainValidation.valid) {
        return res.redirect('/networks?error=' + encodeURIComponent(domainValidation.error || 'Invalid custom domain.'));
    }
    const cleanDomain = domainValidation.value;
    const schools = await master_db_1.MasterDb.getSchools();
    const existing = schools.find((s) => s.id !== school.id && s.customDomain && s.customDomain.toLowerCase() === cleanDomain);
    if (existing) {
        return res.redirect('/networks?error=' + encodeURIComponent(`Domain "${cleanDomain}" is already bound to another school.`));
    }
    await master_db_1.MasterDb.updateSchool(school.id, {
        customDomain: cleanDomain,
        sslStatus: 'active',
    });
    await easypanel_service_1.EasypanelService.registerDomain(cleanDomain);
    res.redirect('/networks');
});
exports.default = router;
