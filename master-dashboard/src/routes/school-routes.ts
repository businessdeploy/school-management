import { Router, Request, Response } from 'express';
import { MasterDb } from '../db/master-db';
import { SeedInstaller } from '../db/seed-installer';
import { FleetDb } from '../db/fleet-db';
import { DockerService } from '../services/docker-service';
import { SsoService } from '../services/sso-service';
import { EasypanelService } from '../services/easypanel-service';
import { OperationsService } from '../services/operations-service';
import { config } from '../config';
import { validateSlug, validateDomain, validateBoundedInt } from '../validation';
import { requirePermission } from '../middleware/permissions';
import { PERMISSIONS } from '../permissions';

const router = Router();

async function renderCreateForm(res: Response, error: string | null) {
  const clients = await MasterDb.getClients();
  const networks = await MasterDb.getNetworks();
  return res.render('school-create', {
    pageTitle: 'Instant School Onboarding Wizard',
    clients,
    networks,
    error,
  });
}

// 1. List Schools
router.get('/', async (req: Request, res: Response) => {
  const hostHeader = (req.headers['x-forwarded-host'] || req.headers.host) as string;
  const currentHost = MasterDb.syncLiveDomain(hostHeader);

  const schools = await MasterDb.getSchools();
  const clients = await MasterDb.getClients();
  const networks = await MasterDb.getNetworks();

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
router.get('/new', async (req: Request, res: Response) => {
  const hostHeader = (req.headers['x-forwarded-host'] || req.headers.host) as string;
  MasterDb.syncLiveDomain(hostHeader);

  return renderCreateForm(res, null);
});

// 3. Create School (End-to-End Onboarding)
router.post('/create', requirePermission(PERMISSIONS.SCHOOLS_CREATE), async (req: Request, res: Response) => {
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

  const slugValidation = validateSlug(slug);
  if (!slugValidation.valid) {
    return renderCreateForm(res, slugValidation.error || 'Invalid slug.');
  }
  const cleanSlug = slugValidation.value as string;

  if (!name || !adminEmail) {
    return renderCreateForm(res, 'School Name and Admin Email are required.');
  }

  // Check uniqueness
  if (await MasterDb.getSchoolBySlug(cleanSlug)) {
    return renderCreateForm(res, `Slug "${cleanSlug}" is already taken. Please choose a different subdomain slug.`);
  }

  const network = await MasterDb.getNetworkById(networkId);
  if (!network) {
    return renderCreateForm(res, 'Selected network is invalid.');
  }

  const storageQuota = validateBoundedInt(storageQuotaGb, 1, 500);
  if (!storageQuota.valid) {
    return renderCreateForm(res, `Storage quota: ${storageQuota.error}`);
  }

  const maxStudentsVal = validateBoundedInt(maxStudents, 1, 100000);
  if (!maxStudentsVal.valid) {
    return renderCreateForm(res, `Max students: ${maxStudentsVal.error}`);
  }

  let cleanCustomDomain: string | undefined;
  if (customDomain) {
    const domainValidation = validateDomain(customDomain);
    if (!domainValidation.valid) {
      return renderCreateForm(res, domainValidation.error || 'Invalid custom domain.');
    }
    cleanCustomDomain = domainValidation.value as string;
  }

  const clients = await MasterDb.getClients();
  const client = clientId ? clients.find((c) => c.id === clientId) : clients[0];
  if (!client) {
    return renderCreateForm(res, 'Selected client is invalid.');
  }

  const subdomain = `${cleanSlug}.${network.rootDomain}`;
  const dbName = `${config.fleetDb.databasePrefix}${cleanSlug}`;
  const containerName = `ss_tenant_${cleanSlug}`;

  try {
    // 1. Save record in master database with status 'provisioning'
    const newSchool = await MasterDb.addSchool({
      slug: cleanSlug,
      name,
      clientId: client.id,
      networkId: network.id,
      subdomain,
      customDomain: cleanCustomDomain,
      dbName,
      containerName,
      adminEmail,
      status: 'provisioning',
      storageQuotaGb: storageQuota.value,
      maxStudents: maxStudentsVal.value,
      sslStatus: cleanCustomDomain ? 'pending' : 'active',
    });

    const operator = (req.session as any)?.user?.username;
    const operationId = await OperationsService.start(
      'school.provision',
      newSchool.id,
      `school.provision.${cleanSlug}`,
      operator
    );

    try {
      // 2. Provision database and seed schema
      await OperationsService.runStep(operationId, 'provision_database', async () => {
        await SeedInstaller.provisionTenantDatabase({
          slug: cleanSlug,
          name,
          domain: cleanCustomDomain || subdomain,
          adminEmail,
          adminPassword: adminPassword || 'Admin@123456',
          currencySymbol: currencySymbol || '$',
          timezone: timezone || 'UTC',
        });
      });

      // 3. Launch isolated container
      await OperationsService.runStep(operationId, 'launch_container', async () => {
        const launched = await DockerService.launchTenantContainer({
           slug: cleanSlug,
           containerName,
           dbName,
           domain: cleanCustomDomain || subdomain,
           ramLimitMb: 512,
         });
        if (!launched) throw new Error('Failed to launch tenant container.');
      });

      // 4. Register Traefik domain in Easypanel (optional)
      await OperationsService.runStep(operationId, 'register_domains', async () => {
        await EasypanelService.registerDomain(subdomain);
        if (cleanCustomDomain) {
          await EasypanelService.registerDomain(cleanCustomDomain);
        }
      });

      // 5. Update status to active
      await MasterDb.updateSchool(newSchool.id, { status: 'active' });
      await OperationsService.finish(operationId, 'succeeded');

      res.redirect(`/schools/${newSchool.id}`);
    } catch (err: any) {
      await MasterDb.updateSchool(newSchool.id, { status: 'stopped' }).catch(() => {});
      await OperationsService.finish(operationId, 'failed').catch(() => {});
      throw err;
    }
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

    const school = await MasterDb.getSchoolById(req.params.id);
    if (!school) return res.redirect('/schools');

    const clients = await MasterDb.getClients();
    const client = clients.find((c) => c.id === school.clientId) || {
      id: school.clientId || 'client_default',
      name: 'Direct Client',
      organization: school.name,
      email: school.adminEmail,
      phone: '',
      plan: 'Starter' as const,
      status: 'active' as const,
      createdAt: school.createdAt,
    };

    const networks = await MasterDb.getNetworks();
    const network = networks.find((n) => n.id === school.networkId) || {
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
router.get('/:id/sso-login', requirePermission(PERMISSIONS.TENANT_ACCESS_ISSUE), async (req: Request, res: Response) => {
  const school = await MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  const operator = (req.session as any)?.user?.username || 'unknown-operator';
  const targetDomain = school.customDomain || school.subdomain;
  const redirectUrl = SsoService.getSsoRedirectUrl({
    schoolDomain: targetDomain,
    schoolSlug: school.slug,
    staffId: 1,
    operator,
    purpose: 'school_access',
  });
  console.log(`[Master SSO] Issued school access grant for ${school.slug} by ${operator}`);
  res.redirect(redirectUrl);
});

// 6. Direct Super Admin Password Reset
router.post('/:id/reset-password', requirePermission(PERMISSIONS.TENANT_ACCESS_ISSUE), async (req: Request, res: Response) => {
  const school = await MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  const { newPassword } = req.body;
  if (!newPassword || newPassword.trim().length < 6) {
    return res.redirect(`/schools/${school.id}?error=Password must be at least 6 characters long.`);
  }

  try {
    await FleetDb.resetAdminPassword(school.dbName, school.adminEmail, newPassword.trim());
    res.redirect(`/schools/${school.id}?success=Super Admin password reset successfully.`);
  } catch (err: any) {
    console.error('[Password Reset Error]:', err);
    res.redirect(`/schools/${school.id}?error=Failed to reset password.`);
  }
});

// 7. 1-Click Database SQL Backup Download
router.get('/:id/backup-db', requirePermission(PERMISSIONS.BACKUPS_DOWNLOAD), async (req: Request, res: Response) => {
  const school = await MasterDb.getSchoolById(req.params.id);
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
router.post('/:id/edit', requirePermission(PERMISSIONS.SCHOOLS_EDIT), async (req: Request, res: Response) => {
  const school = await MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  const { name, adminEmail, customDomain, storageQuotaGb, maxStudents, status } = req.body;

  const allowedStatuses = ['active', 'suspended', 'stopped'];
  const nextStatus = status ? String(status) : school.status;
  if (!allowedStatuses.includes(nextStatus)) {
    return res.redirect(`/schools/${school.id}?error=Invalid status.`);
  }

  const storageQuota = validateBoundedInt(storageQuotaGb, 1, 500);
  if (!storageQuota.valid) {
    return res.redirect(`/schools/${school.id}?error=${encodeURIComponent(`Storage quota: ${storageQuota.error}`)}`);
  }

  const maxStudentsVal = validateBoundedInt(maxStudents, 1, 100000);
  if (!maxStudentsVal.valid) {
    return res.redirect(`/schools/${school.id}?error=${encodeURIComponent(`Max students: ${maxStudentsVal.error}`)}`);
  }

  let cleanDomain: string | undefined;
  if (customDomain) {
    const domainValidation = validateDomain(customDomain);
    if (!domainValidation.valid) {
      return res.redirect(`/schools/${school.id}?error=${encodeURIComponent(domainValidation.error || 'Invalid custom domain.')}`);
    }
    cleanDomain = domainValidation.value as string;
  }

  try {
    await MasterDb.updateSchool(school.id, {
      name: name ? name.trim() : school.name,
      adminEmail: adminEmail ? adminEmail.trim() : school.adminEmail,
      customDomain: cleanDomain,
      storageQuotaGb: storageQuota.value,
      maxStudents: maxStudentsVal.value,
      status: nextStatus as any,
      sslStatus: cleanDomain ? 'pending' : school.sslStatus,
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
    res.redirect(`/schools/${school.id}?error=Failed to update configuration.`);
  }
});

// 9. Quick Status Toggle
router.post('/:id/set-status', requirePermission(PERMISSIONS.SCHOOLS_LIFECYCLE), async (req: Request, res: Response) => {
  const school = await MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  const { status } = req.body;
  if (!['active', 'suspended', 'stopped'].includes(status)) {
    return res.redirect(`/schools/${school.id}?error=Invalid status.`);
  }

  if (status === 'active') {
    const ok = await DockerService.startContainer(school.containerName);
    if (!ok) return res.redirect(`/schools/${school.id}?error=Container failed to start.`);
  } else if (status === 'stopped') {
    const ok = await DockerService.stopContainer(school.containerName);
    if (!ok) return res.redirect(`/schools/${school.id}?error=Container failed to stop.`);
  }

  await MasterDb.updateSchool(school.id, { status });
  res.redirect(`/schools/${school.id}?success=School status set to ${status}.`);
});

// 10. Lifecycle Actions
router.post('/:id/start', requirePermission(PERMISSIONS.SCHOOLS_LIFECYCLE), async (req: Request, res: Response) => {
  const school = await MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  const ok = await DockerService.startContainer(school.containerName);
  if (!ok) return res.redirect(`/schools/${school.id}?error=Container failed to start.`);

  await MasterDb.updateSchool(school.id, { status: 'active' });
  res.redirect(`/schools/${school.id}?success=Container started successfully.`);
});

router.post('/:id/stop', requirePermission(PERMISSIONS.SCHOOLS_LIFECYCLE), async (req: Request, res: Response) => {
  const school = await MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  const ok = await DockerService.stopContainer(school.containerName);
  if (!ok) return res.redirect(`/schools/${school.id}?error=Container failed to stop.`);

  await MasterDb.updateSchool(school.id, { status: 'stopped' });
  res.redirect(`/schools/${school.id}?success=Container stopped.`);
});

router.post('/:id/restart', requirePermission(PERMISSIONS.SCHOOLS_LIFECYCLE), async (req: Request, res: Response) => {
  const school = await MasterDb.getSchoolById(req.params.id);
  if (!school) return res.redirect('/schools');

  const ok = await DockerService.restartContainer(school.containerName);
  if (!ok) return res.redirect(`/schools/${school.id}?error=Container failed to restart.`);

  res.redirect(`/schools/${school.id}?success=Container restarted successfully.`);
});

router.post('/:id/suspend', requirePermission(PERMISSIONS.SCHOOLS_LIFECYCLE), async (req: Request, res: Response) => {
  const school = await MasterDb.getSchoolById(req.params.id);
  if (school) {
    await MasterDb.updateSchool(school.id, { status: 'suspended' });
  }
  res.redirect(`/schools/${req.params.id}?success=School suspended. Public traffic blocked.`);
});

router.post('/:id/activate', requirePermission(PERMISSIONS.SCHOOLS_LIFECYCLE), async (req: Request, res: Response) => {
  const school = await MasterDb.getSchoolById(req.params.id);
  if (school) {
    await MasterDb.updateSchool(school.id, { status: 'active' });
  }
  res.redirect(`/schools/${req.params.id}?success=School reactivated.`);
});

router.post('/:id/delete', requirePermission(PERMISSIONS.SCHOOLS_PURGE), async (req: Request, res: Response) => {
  const school = await MasterDb.getSchoolById(req.params.id);
  if (school) {
    await DockerService.removeContainer(school.containerName);
    await MasterDb.deleteSchool(school.id);
  }
  res.redirect('/schools?success=School permanently deleted.');
});

export default router;
