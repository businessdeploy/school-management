import { Router, Request, Response } from 'express';
import { MasterDb } from '../db/master-db';
import { config } from '../config';

const router = Router();

/**
 * Caddy On-Demand TLS Webhook
 * Caddy makes an HTTP GET request here before issuing a Let's Encrypt certificate:
 * GET /api/v1/domains/validate?domain=portal.greenwoodhigh.edu
 */
router.get('/validate', (req: Request, res: Response) => {
  const domain = (req.query.domain as string || '').toLowerCase().trim();

  if (!domain) {
    return res.status(400).json({ allowed: false, error: 'Domain parameter missing' });
  }

  // 1. Allow Master Dashboard domain
  if (domain === config.masterDomain.toLowerCase() || domain.startsWith('localhost')) {
    return res.status(200).send('Domain allowed for Master Dashboard');
  }

  // 2. Check if domain belongs to an active school
  const school = MasterDb.getSchoolByDomain(domain);
  if (school && school.status !== 'suspended') {
    console.log(`[Caddy TLS Webhook] Approving SSL certificate for: ${domain} (${school.name})`);
    return res.status(200).send('Domain allowed for school');
  }

  // 3. Check if domain matches any root network wildcard
  const networks = MasterDb.getNetworks();
  const matchesNetwork = networks.some((n) => domain.endsWith(`.${n.rootDomain.toLowerCase()}`));
  if (matchesNetwork) {
    console.log(`[Caddy TLS Webhook] Approving SSL certificate for network subdomain: ${domain}`);
    return res.status(200).send('Domain allowed under authorized network');
  }

  console.warn(`[Caddy TLS Webhook] Denying SSL certificate for unauthorized domain: ${domain}`);
  return res.status(403).send('Unauthorized domain');
});

export default router;
