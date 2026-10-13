import { Router, Request, Response } from 'express';
import { MasterDb } from '../db/master-db';
import { DnsService } from '../services/dns-service';
import { EasypanelService } from '../services/easypanel-service';
import { validateDomain } from '../validation';
import { requirePermission } from '../middleware/permissions';
import { PERMISSIONS } from '../permissions';

const router = Router();

router.get('/', async (req: Request, res: Response) => {
  const networks = await MasterDb.getNetworks();
  const schools = await MasterDb.getSchools();
  res.render('networks', {
    pageTitle: 'Multi-Network & Custom Domain Routing',
    networks,
    schools,
    dnsResult: null,
    error: req.query.error || null,
    success: req.query.success || null,
  });
});

router.post('/create', requirePermission(PERMISSIONS.NETWORKS_MANAGE), async (req: Request, res: Response) => {
  const { name, rootDomain, description } = req.body;
  if (!name) {
    return res.redirect('/networks?error=' + encodeURIComponent('Network name is required.'));
  }

  const domainValidation = validateDomain(rootDomain);
  if (!domainValidation.valid) {
    return res.redirect('/networks?error=' + encodeURIComponent(domainValidation.error || 'Invalid root domain.'));
  }
  const cleanRootDomain = domainValidation.value as string;

  const networks = await MasterDb.getNetworks();
  const existing = networks.find((n) => n.rootDomain.toLowerCase() === cleanRootDomain);
  if (existing) {
    return res.redirect('/networks?error=' + encodeURIComponent(`Root domain "${cleanRootDomain}" is already registered.`));
  }

  await MasterDb.addNetwork({
    name: name.trim(),
    rootDomain: cleanRootDomain,
    isDefault: false,
    description: description ? description.trim() : undefined,
  });
  res.redirect('/networks');
});

router.post('/verify-domain', requirePermission(PERMISSIONS.NETWORKS_MANAGE), async (req: Request, res: Response) => {
  const { domain, expectedTarget } = req.body;
  const networks = await MasterDb.getNetworks();
  const schools = await MasterDb.getSchools();

  const target = expectedTarget || 'ingress.yournetwork.com';
  const dnsResult = await DnsService.verifyDomain(domain, target);

  res.render('networks', {
    pageTitle: 'Multi-Network & Custom Domain Routing',
    networks,
    schools,
    dnsResult,
  });
});

router.post('/bind-domain', requirePermission(PERMISSIONS.NETWORKS_MANAGE), async (req: Request, res: Response) => {
  const { schoolId, customDomain } = req.body;

  const school = await MasterDb.getSchoolById(schoolId);
  if (!school) {
    return res.redirect('/networks?error=' + encodeURIComponent('Selected school is invalid.'));
  }

  const domainValidation = validateDomain(customDomain);
  if (!domainValidation.valid) {
    return res.redirect('/networks?error=' + encodeURIComponent(domainValidation.error || 'Invalid custom domain.'));
  }
  const cleanDomain = domainValidation.value as string;

  const schools = await MasterDb.getSchools();
  const existing = schools.find(
    (s) => s.id !== school.id && s.customDomain && s.customDomain.toLowerCase() === cleanDomain
  );
  if (existing) {
    return res.redirect('/networks?error=' + encodeURIComponent(`Domain "${cleanDomain}" is already bound to another school.`));
  }

  await MasterDb.updateSchool(school.id, {
    customDomain: cleanDomain,
    sslStatus: 'pending',
  });
  await EasypanelService.registerDomain(cleanDomain);
  res.redirect('/networks');
});

export default router;
