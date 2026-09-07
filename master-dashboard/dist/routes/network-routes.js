"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const master_db_1 = require("../db/master-db");
const dns_service_1 = require("../services/dns-service");
const easypanel_service_1 = require("../services/easypanel-service");
const router = (0, express_1.Router)();
router.get('/', (req, res) => {
    const networks = master_db_1.MasterDb.getNetworks();
    const schools = master_db_1.MasterDb.getSchools();
    res.render('networks', {
        pageTitle: 'Multi-Network & Custom Domain Routing',
        networks,
        schools,
        dnsResult: null,
    });
});
router.post('/create', (req, res) => {
    const { name, rootDomain, description } = req.body;
    if (name && rootDomain) {
        master_db_1.MasterDb.addNetwork({
            name,
            rootDomain: rootDomain.toLowerCase().trim(),
            isDefault: false,
            description,
        });
    }
    res.redirect('/networks');
});
router.post('/verify-domain', async (req, res) => {
    const { domain, expectedTarget } = req.body;
    const networks = master_db_1.MasterDb.getNetworks();
    const schools = master_db_1.MasterDb.getSchools();
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
    if (schoolId && customDomain) {
        const cleanDomain = customDomain.trim().toLowerCase();
        master_db_1.MasterDb.updateSchool(schoolId, {
            customDomain: cleanDomain,
            sslStatus: 'active',
        });
        await easypanel_service_1.EasypanelService.registerDomain(cleanDomain);
    }
    res.redirect('/networks');
});
exports.default = router;
