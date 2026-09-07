import { Router, Request, Response } from 'express';
import { MasterDb } from '../db/master-db';
import { DnsService } from '../services/dns-service';

const router = Router();

router.get('/', (req: Request, res: Response) => {
  const networks = MasterDb.getNetworks();
  const schools = MasterDb.getSchools();
  res.render('networks', {
    pageTitle: 'Multi-Network & Custom Domain Routing',
    networks,
    schools,
    dnsResult: null,
  });
});

router.post('/create', (req: Request, res: Response) => {
  const { name, rootDomain, description } = req.body;
  if (name && rootDomain) {
    MasterDb.addNetwork({
      name,
      rootDomain: rootDomain.toLowerCase().trim(),
      isDefault: false,
      description,
    });
  }
  res.redirect('/networks');
});

router.post('/verify-domain', async (req: Request, res: Response) => {
  const { domain, expectedTarget } = req.body;
  const networks = MasterDb.getNetworks();
  const schools = MasterDb.getSchools();

  const target = expectedTarget || 'ingress.yournetwork.com';
  const dnsResult = await DnsService.verifyDomain(domain, target);

  res.render('networks', {
    pageTitle: 'Multi-Network & Custom Domain Routing',
    networks,
    schools,
    dnsResult,
  });
});

router.post('/bind-domain', (req: Request, res: Response) => {
  const { schoolId, customDomain } = req.body;
  if (schoolId && customDomain) {
    MasterDb.updateSchool(schoolId, {
      customDomain: customDomain.trim().toLowerCase(),
      sslStatus: 'active',
    });
  }
  res.redirect('/networks');
});

export default router;
