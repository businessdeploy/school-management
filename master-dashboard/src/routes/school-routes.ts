import { Router, Request, Response } from 'express';
import { MasterDb } from '../db/master-db';
import { SeedInstaller } from '../db/seed-installer';
import { DockerService } from '../services/docker-service';
import { SsoService } from '../services/sso-service';
import { config } from '../config';

const router = Router();

// 1. List Schools
router.get('/', async (req: Request, res: Response) => {
  const schools = MasterDb.getSchools();
  const clients = MasterDb.getClients();
  const networks = MasterDb.getNetworks();

  // Attach client and network details
  const enrichedSchools = schools.map((s) => ({
    ...s,
    client: clients.find((c) => c.id === s.clientId),
    network: networks.find((n) => n.id === s.networkId),
  }));

  res.render('schools', {
    pageTitle: 'School Fleet Management',
    schools: enrichedSchools,
    totalSchools: schools.length,
    activeCount: schools.filter((s) => s.status === 'active').length,
    suspendedCount: schools.filter((s) => s.status === 'suspended').length,
  });
});

// 2. New School Form
router.get('/new', (req: Request, res: Response) => {
  const clients = MasterDb.getClients();
  const networks = MasterDb.getNetworks();
  res.render('school-create', {
    pageTitle: 'Instant School Onboarding Wizard',
    clients,
    networks,
    error: null,
  });
});

// 3. Create School (End-to-End Onboarding)
router.post('/create', async (req: Request, res: Response) => {
  const {
    name,
    slug,
    clientId,
    networkId,
    customDomain,
    adminEmail,
    adminPassword,
    currencySymbol,
    timezone,
    storageQuotaGb,
    maxStudents,
  } = req.body;

  // Clean slug: lowercase alphanumeric and hyphens only
  const cleanSlug = (slug || '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9-]/g, '');

  if (!cleanSlug || !name || !adminEmail) {
    const clients = MasterDb.getClients();
    const networks = MasterDb.getNetworks();
    return res.render('school-create', {
      pageTitle: 'Instant School Onboarding Wizard',
      clients,
      networks,
      error: 'School Name, Subdomain Slug, and Admin Email are required.',
    });
  }

  // Check uniqueness
  if (MasterDb.getSchoolBySlug(cleanSlug)) {
    const clients = MasterDb.getClients();
    const networks = MasterDb.getNetworks();
    return res.render('school-create', {
      pageTitle: 'Instant School Onboarding Wizard',
      clients,
      networks,
      error: `Slug "${cleanSlug}" is already taken. Please choose a different subdomain slug.`,
    });
  }

  const network = MasterDb.getNetworkById(networkId) || MasterDb.getNetworks()[0];
  const subdomain = `${cleanSlug}.${network.rootDomain}`;
  const dbName = `${config.fleetDb.databasePrefix}${cleanSlug}`;
  const containerName = `ss_tenant_${cleanSlug}`;

  try {
    // 1. Save record in master database with status 'provisioning'
    const newSchool = MasterDb.addSchool({
      slug: cleanSlug,
      name,
      clientId: clientId || 'client_demo',
      networkId: network.id,
      subdomain,
      customDomain: customDomain ? customDomain.trim().toLowerCase() : undefined,
      dbName,
      containerName,
      adminEmail,
      status: 'provisioning',
      storageQuotaGb: parseInt(storageQuotaGb || '10', 10),
      maxStudents: parseInt(maxStudents || '1000', 10),
      sslStatus: customDomain ? 'pending' : 'active',
    });

    // 2. Provision database and seed schema
    await SeedInstaller.provisionTenantDatabase({
      slug: cleanSlug,
      name,
      domain: customDomain || subdomain,
      adminEmail,
      adminPassword: adminPassword || 'Admin@123456',
      currencySymbol: currencySymbol || '$',
      timezone: timezone || 'UTC',
    });

    // 3. Launch isolated container
    await DockerService.launchTenantContainer({
      slug: cleanSlug,
      containerName,
      dbName,
      domain: customDomain || subdomain,
      ramLimitMb: 512,
    });

    // 4. Update status to active
    MasterDb.updateSchool(newSchool.id, { status: 'active' });

    res.redirect(`/schools/${newSchool.id}`);
  } catch (err: any) {
    console.error('[Onboarding Error]:', err);
    res.redirect('/schools?error=' + encodeURIComponent(err.message));
  }
});

// 4. School Details
router.get('/:id', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  const client = MasterDb.getClients().find((c) => c.id === school.clientId);
  const network = MasterDb.getNetworks().find((n) => n.id === school.networkId);
  const containerStatus = await DockerService.checkContainerStatus(school.containerName);
  const logs = await DockerService.getLogs(school.containerName, 50);

  // Generate 1-click SSO link
  const ssoUrl = `/schools/${school.id}/sso-login`;

  res.render('school-detail', {
    pageTitle: `${school.name} - Fleet Overview`,
    school,
    client,
    network,
    containerStatus,
    logs,
    ssoUrl,
  });
});

// 5. 1-Click Master Admin SSO Login (Direct Impersonation)
router.get('/:id/sso-login', (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  const targetDomain = school.customDomain || school.subdomain;
  const redirectUrl = SsoService.getSsoRedirectUrl(targetDomain, school.slug, 1);
  console.log(`[Master SSO] Generating 1-click login for ${school.name} -> ${redirectUrl}`);
  res.redirect(redirectUrl);
});

// 6. Lifecycle Actions
router.post('/:id/start', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (school) {
    await DockerService.startContainer(school.containerName);
    MasterDb.updateSchool(school.id, { status: 'active' });
  }
  res.redirect(`/schools/${req.params.id}`);
});

router.post('/:id/stop', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (school) {
    await DockerService.stopContainer(school.containerName);
    MasterDb.updateSchool(school.id, { status: 'stopped' });
  }
  res.redirect(`/schools/${req.params.id}`);
});

router.post('/:id/restart', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (school) {
    await DockerService.restartContainer(school.containerName);
  }
  res.redirect(`/schools/${req.params.id}`);
});

router.post('/:id/suspend', (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (school) {
    MasterDb.updateSchool(school.id, { status: 'suspended' });
  }
  res.redirect(`/schools/${req.params.id}`);
});

router.post('/:id/activate', (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (school) {
    MasterDb.updateSchool(school.id, { status: 'active' });
  }
  res.redirect(`/schools/${req.params.id}`);
});

router.post('/:id/delete', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (school) {
    await DockerService.removeContainer(school.containerName);
    MasterDb.deleteSchool(school.id);
  }
  res.redirect('/schools');
});

export default router;
