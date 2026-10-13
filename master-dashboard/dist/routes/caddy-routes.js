"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const master_db_1 = require("../db/master-db");
const config_1 = require("../config");
const router = (0, express_1.Router)();
/**
 * Caddy On-Demand TLS Webhook
 * Caddy makes an HTTP GET request here before issuing a Let's Encrypt certificate:
 * GET /api/v1/domains/validate?domain=portal.greenwoodhigh.edu
 */
router.get('/validate', async (req, res) => {
    const domain = (req.query.domain || '').toLowerCase().trim();
    if (!domain) {
        return res.status(400).json({ allowed: false, error: 'Domain parameter missing' });
    }
    // 1. Allow Master Dashboard domain
    if (domain === config_1.config.masterDomain.toLowerCase() || domain.startsWith('localhost')) {
        return res.status(200).send('Domain allowed for Master Dashboard');
    }
    // 2. Check if domain belongs to an active school
    const school = await master_db_1.MasterDb.getSchoolByDomain(domain);
    if (school && school.status !== 'suspended') {
        console.log(`[Caddy TLS Webhook] Approving SSL certificate for: ${domain} (${school.name})`);
        return res.status(200).send('Domain allowed for school');
    }
    console.warn(`[Caddy TLS Webhook] Denying SSL certificate for unauthorized domain: ${domain}`);
    return res.status(403).send('Unauthorized domain');
});
exports.default = router;
