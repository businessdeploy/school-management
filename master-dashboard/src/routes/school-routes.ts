import { Router, Request, Response } from 'express';
import { MasterDb } from '../db/master-db';
import { SeedInstaller } from '../db/seed-installer';
import { FleetDb } from '../db/fleet-db';
import { DockerService } from '../services/docker-service';
import { SsoService } from '../services/sso-service';
import { EasypanelService } from '../services/easypanel-service';
import { config } from '../config';

const router = Router();

// 1. List Schools
router.get('/', async (req: Request, res: Response) => {
  const hostHeader = (req.headers['x-forwarded-host'] || req.headers.host) as string;
  const currentHost = MasterDb.syncLiveDomain(hostHeader);

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
    currentHost,
    success: req.query.success || null,
    error: req.query.error || null,
  });
});

// 2. New School Form
router.get('/new', (req: Request, res: Response) => {
  const hostHeader = (req.headers['x-forwarded-host'] || req.headers.host) as string;
  MasterDb.syncLiveDomain(hostHeader);

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

    // 4. Register Traefik domain in Easypanel for instant live access
    await EasypanelService.registerDomain(subdomain);
    if (customDomain) {
      await EasypanelService.registerDomain(customDomain);
    }

    // 5. Update status to active
    MasterDb.updateSchool(newSchool.id, { status: 'active' });

    res.redirect(`/schools/${newSchool.id}`);
  } catch (err: any) {
    console.error('[Onboarding Error]:', err);
    res.redirect('/schools?error=' + encodeURIComponent(err.message));
  }
});

// 4. School Details (High-Control Management Console)
router.get('/:id', async (req: Request, res: Response, next: any) => {
  try {
    const hostHeader = (req.headers['x-forwarded-host'] || req.headers.host) as string;
    const currentHost = MasterDb.syncLiveDomain(hostHeader);

    const school = MasterDb.getSchoolById(req.params.id);
    if (!school) return res.redirect('/schools');

    const client = MasterDb.getClients().find((c) => c.id === school.clientId) || {
      id: school.clientId || 'client_default',
      name: 'Direct Client',
      organization: school.name,
      email: school.adminEmail,
      phone: '',
      plan: 'Starter' as const,
      status: 'active' as const,
      createdAt: school.createdAt,
    };

    const network = MasterDb.getNetworks().find((n) => n.id === school.networkId) || {
      id: school.networkId || 'net_default',
      name: 'Primary Network Fleet',
      rootDomain: currentHost || config.defaultNetworkDomain,
      isDefault: true,
      createdAt: school.createdAt,
    };

    // Live MariaDB Telemetry
    const dbStats = await FleetDb.getTenantStats(school.dbName);

    let containerStatus: 'running' | 'stopped' | 'not_found' = 'stopped';
    try {
      containerStatus = await DockerService.checkContainerStatus(school.containerName);
    } catch (e: any) {
      containerStatus = 'not_found';
    }

    let logs = 'No logs recorded.';
    try {
      logs = await DockerService.getLogs(school.containerName, 50);
    } catch (e: any) {
      logs = `Container logs offline: ${e.message}`;
    }

    // Generate 1-click SSO link
    const ssoUrl = `/schools/${school.id}/sso-login`;

    res.render('school-detail', {
      pageTitle: `${school.name} - Fleet Overview`,
      school,
      schoolClient: client,
      network,
      currentHost,
      dbStats,
      containerStatus,
      logs: typeof logs === 'string' ? logs : String(logs),
      ssoUrl,
      success: req.query.success || null,
      error: req.query.error || null,
    });
  } catch (err: any) {
    console.error(`[School Detail Error for ${req.params.id}]:`, err);
    next(err);
  }
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

// 6. Direct Super Admin Password Reset
router.post('/:id/reset-password', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  const { newPassword } = req.body;
  if (!newPassword || newPassword.trim().length < 6) {
    return res.redirect(`/schools/${school.id}?error=Password must be at least 6 characters long.`);
  }

  try {
    await FleetDb.resetAdminPassword(school.dbName, school.adminEmail, newPassword.trim());
    res.redirect(`/schools/${school.id}?success=Super Admin password successfully reset to "${newPassword.trim()}".`);
  } catch (err: any) {
    console.error('[Password Reset Error]:', err);
    res.redirect(`/schools/${school.id}?error=Failed to reset password: ${encodeURIComponent(err.message)}`);
  }
});

// 7. 1-Click Database SQL Backup Download
router.get('/:id/backup-db', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  try {
    const sqlDump = await FleetDb.generateSqlDump(school.dbName, school.name, school.slug);
    const filename = `${school.slug}_backup_${Date.now()}.sql`;

    res.setHeader('Content-Type', 'application/sql');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(sqlDump);
  } catch (err: any) {
    console.error('[Backup Error]:', err);
    res.redirect(`/schools/${school.id}?error=Database backup failed: ${encodeURIComponent(err.message)}`);
  }
});

// 8. Update School Configuration & Quotas
router.post('/:id/edit', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  const { name, adminEmail, customDomain, storageQuotaGb, maxStudents, status } = req.body;

  try {
    const cleanDomain = customDomain ? customDomain.trim().toLowerCase().replace(/^https?:\/\//, '').replace(/\/$/, '') : undefined;

    MasterDb.updateSchool(school.id, {
      name: name ? name.trim() : school.name,
      adminEmail: adminEmail ? adminEmail.trim() : school.adminEmail,
      customDomain: cleanDomain || undefined,
      storageQuotaGb: storageQuotaGb ? parseInt(storageQuotaGb, 10) : school.storageQuotaGb,
      maxStudents: maxStudents ? parseInt(maxStudents, 10) : school.maxStudents,
      status: status || school.status,
      sslStatus: cleanDomain ? 'active' : school.sslStatus,
    });

    // Also update tenant sch_settings table
    if (name || adminEmail) {
      await FleetDb.updateSchoolSettings(
        school.dbName,
        name ? name.trim() : school.name,
        adminEmail ? adminEmail.trim() : school.adminEmail
      );
    }

    res.redirect(`/schools/${school.id}?success=School configuration updated successfully.`);
  } catch (err: any) {
    console.error('[School Edit Error]:', err);
    res.redirect(`/schools/${school.id}?error=Failed to update configuration: ${encodeURIComponent(err.message)}`);
  }
});

// 9. Quick Status Toggle
router.post('/:id/set-status', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  const { status } = req.body;
  if (['active', 'suspended', 'stopped'].includes(status)) {
    MasterDb.updateSchool(school.id, { status });
    if (status === 'active') {
      await DockerService.startContainer(school.containerName);
    } else if (status === 'stopped') {
      await DockerService.stopContainer(school.containerName);
    }
    res.redirect(`/schools/${school.id}?success=School status set to ${status}.`);
  } else {
    res.redirect(`/schools/${school.id}?error=Invalid status.`);
  }
});

// 10. Lifecycle Actions
router.post('/:id/start', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (school) {
    await DockerService.startContainer(school.containerName);
    MasterDb.updateSchool(school.id, { status: 'active' });
  }
  res.redirect(`/schools/${req.params.id}?success=Container started successfully.`);
});

router.post('/:id/stop', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (school) {
    await DockerService.stopContainer(school.containerName);
    MasterDb.updateSchool(school.id, { status: 'stopped' });
  }
  res.redirect(`/schools/${req.params.id}?success=Container stopped.`);
});

router.post('/:id/restart', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (school) {
    await DockerService.restartContainer(school.containerName);
  }
  res.redirect(`/schools/${req.params.id}?success=Container restarted successfully.`);
});

router.post('/:id/suspend', (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (school) {
    MasterDb.updateSchool(school.id, { status: 'suspended' });
  }
  res.redirect(`/schools/${req.params.id}?success=School suspended. Public traffic blocked.`);
});

router.post('/:id/activate', (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (school) {
    MasterDb.updateSchool(school.id, { status: 'active' });
  }
  res.redirect(`/schools/${req.params.id}?success=School reactivated.`);
});

router.post('/:id/delete', async (req: Request, res: Response) => {
  const school = MasterDb.getSchoolById(req.params.id);
  if (school) {
    await DockerService.removeContainer(school.containerName);
    MasterDb.deleteSchool(school.id);
  }
  res.redirect('/schools?success=School permanently deleted.');
});

export default router;
