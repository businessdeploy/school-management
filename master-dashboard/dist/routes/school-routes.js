"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const master_db_1 = require("../db/master-db");
const seed_installer_1 = require("../db/seed-installer");
const fleet_db_1 = require("../db/fleet-db");
const docker_service_1 = require("../services/docker-service");
const sso_service_1 = require("../services/sso-service");
const easypanel_service_1 = require("../services/easypanel-service");
const operations_service_1 = require("../services/operations-service");
const config_1 = require("../config");
const validation_1 = require("../validation");
const permissions_1 = require("../middleware/permissions");
const permissions_2 = require("../permissions");
const router = (0, express_1.Router)();
async function renderCreateForm(res, error) {
    const clients = await master_db_1.MasterDb.getClients();
    const networks = await master_db_1.MasterDb.getNetworks();
    return res.render('school-create', {
        pageTitle: 'Instant School Onboarding Wizard',
        clients,
        networks,
        error,
    });
}
// 1. List Schools
router.get('/', async (req, res) => {
    const hostHeader = (req.headers['x-forwarded-host'] || req.headers.host);
    const currentHost = master_db_1.MasterDb.syncLiveDomain(hostHeader);
    const schools = await master_db_1.MasterDb.getSchools();
    const clients = await master_db_1.MasterDb.getClients();
    const networks = await master_db_1.MasterDb.getNetworks();
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
router.get('/new', async (req, res) => {
    const hostHeader = (req.headers['x-forwarded-host'] || req.headers.host);
    master_db_1.MasterDb.syncLiveDomain(hostHeader);
    return renderCreateForm(res, null);
});
// 3. Create School (End-to-End Onboarding)
router.post('/create', (0, permissions_1.requirePermission)(permissions_2.PERMISSIONS.SCHOOLS_CREATE), async (req, res) => {
    const { name, slug, clientId, networkId, customDomain, adminEmail, adminPassword, currencySymbol, timezone, storageQuotaGb, maxStudents, } = req.body;
    const slugValidation = (0, validation_1.validateSlug)(slug);
    if (!slugValidation.valid) {
        return renderCreateForm(res, slugValidation.error || 'Invalid slug.');
    }
    const cleanSlug = slugValidation.value;
    if (!name || !adminEmail) {
        return renderCreateForm(res, 'School Name and Admin Email are required.');
    }
    // Check uniqueness
    if (await master_db_1.MasterDb.getSchoolBySlug(cleanSlug)) {
        return renderCreateForm(res, `Slug "${cleanSlug}" is already taken. Please choose a different subdomain slug.`);
    }
    const network = await master_db_1.MasterDb.getNetworkById(networkId);
    if (!network) {
        return renderCreateForm(res, 'Selected network is invalid.');
    }
    const storageQuota = (0, validation_1.validateBoundedInt)(storageQuotaGb, 1, 500);
    if (!storageQuota.valid) {
        return renderCreateForm(res, `Storage quota: ${storageQuota.error}`);
    }
    const maxStudentsVal = (0, validation_1.validateBoundedInt)(maxStudents, 1, 100000);
    if (!maxStudentsVal.valid) {
        return renderCreateForm(res, `Max students: ${maxStudentsVal.error}`);
    }
    let cleanCustomDomain;
    if (customDomain) {
        const domainValidation = (0, validation_1.validateDomain)(customDomain);
        if (!domainValidation.valid) {
            return renderCreateForm(res, domainValidation.error || 'Invalid custom domain.');
        }
        cleanCustomDomain = domainValidation.value;
    }
    const clients = await master_db_1.MasterDb.getClients();
    const client = clientId ? clients.find((c) => c.id === clientId) : clients[0];
    if (!client) {
        return renderCreateForm(res, 'Selected client is invalid.');
    }
    const subdomain = `${cleanSlug}.${network.rootDomain}`;
    const dbName = `${config_1.config.fleetDb.databasePrefix}${cleanSlug}`;
    const containerName = `ss_tenant_${cleanSlug}`;
    try {
        // 1. Save record in master database with status 'provisioning'
        const newSchool = await master_db_1.MasterDb.addSchool({
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
        const operator = req.session?.user?.username;
        const operationId = await operations_service_1.OperationsService.start('school.provision', newSchool.id, `school.provision.${cleanSlug}`, operator);
        try {
            // 2. Provision database and seed schema
            await operations_service_1.OperationsService.runStep(operationId, 'provision_database', async () => {
                await seed_installer_1.SeedInstaller.provisionTenantDatabase({
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
            await operations_service_1.OperationsService.runStep(operationId, 'launch_container', async () => {
                const launched = await docker_service_1.DockerService.launchTenantContainer({
                    slug: cleanSlug,
                    containerName,
                    dbName,
                    domain: cleanCustomDomain || subdomain,
                    ramLimitMb: 512,
                });
                if (!launched)
                    throw new Error('Failed to launch tenant container.');
            });
            // 4. Register Traefik domain in Easypanel (optional)
            await operations_service_1.OperationsService.runStep(operationId, 'register_domains', async () => {
                await easypanel_service_1.EasypanelService.registerDomain(subdomain);
                if (cleanCustomDomain) {
                    await easypanel_service_1.EasypanelService.registerDomain(cleanCustomDomain);
                }
            });
            // 5. Update status to active
            await master_db_1.MasterDb.updateSchool(newSchool.id, { status: 'active' });
            await operations_service_1.OperationsService.finish(operationId, 'succeeded');
            res.redirect(`/schools/${newSchool.id}`);
        }
        catch (err) {
            await master_db_1.MasterDb.updateSchool(newSchool.id, { status: 'stopped' }).catch(() => { });
            await operations_service_1.OperationsService.finish(operationId, 'failed').catch(() => { });
            throw err;
        }
    }
    catch (err) {
        console.error('[Onboarding Error]:', err);
        res.redirect('/schools?error=' + encodeURIComponent(err.message));
    }
});
// 4. School Details (High-Control Management Console)
router.get('/:id', async (req, res, next) => {
    try {
        const hostHeader = (req.headers['x-forwarded-host'] || req.headers.host);
        const currentHost = master_db_1.MasterDb.syncLiveDomain(hostHeader);
        const school = await master_db_1.MasterDb.getSchoolById(req.params.id);
        if (!school)
            return res.redirect('/schools');
        const clients = await master_db_1.MasterDb.getClients();
        const client = clients.find((c) => c.id === school.clientId) || {
            id: school.clientId || 'client_default',
            name: 'Direct Client',
            organization: school.name,
            email: school.adminEmail,
            phone: '',
            plan: 'Starter',
            status: 'active',
            createdAt: school.createdAt,
        };
        const networks = await master_db_1.MasterDb.getNetworks();
        const network = networks.find((n) => n.id === school.networkId) || {
            id: school.networkId || 'net_default',
            name: 'Primary Network Fleet',
            rootDomain: currentHost || config_1.config.defaultNetworkDomain,
            isDefault: true,
            createdAt: school.createdAt,
        };
        // Live MariaDB Telemetry
        const dbStats = await fleet_db_1.FleetDb.getTenantStats(school.dbName);
        let containerStatus = 'stopped';
        try {
            containerStatus = await docker_service_1.DockerService.checkContainerStatus(school.containerName);
        }
        catch (e) {
            containerStatus = 'not_found';
        }
        let logs = 'No logs recorded.';
        try {
            logs = await docker_service_1.DockerService.getLogs(school.containerName, 50);
        }
        catch (e) {
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
    }
    catch (err) {
        console.error(`[School Detail Error for ${req.params.id}]:`, err);
        next(err);
    }
});
// 5. 1-Click Master Admin SSO Login (Direct Impersonation)
router.get('/:id/sso-login', (0, permissions_1.requirePermission)(permissions_2.PERMISSIONS.TENANT_ACCESS_ISSUE), async (req, res) => {
    const school = await master_db_1.MasterDb.getSchoolById(req.params.id);
    if (!school)
        return res.redirect('/schools');
    const operator = req.session?.user?.username || 'unknown-operator';
    const targetDomain = school.customDomain || school.subdomain;
    const redirectUrl = sso_service_1.SsoService.getSsoRedirectUrl({
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
router.post('/:id/reset-password', (0, permissions_1.requirePermission)(permissions_2.PERMISSIONS.TENANT_ACCESS_ISSUE), async (req, res) => {
    const school = await master_db_1.MasterDb.getSchoolById(req.params.id);
    if (!school)
        return res.redirect('/schools');
    const { newPassword } = req.body;
    if (!newPassword || newPassword.trim().length < 6) {
        return res.redirect(`/schools/${school.id}?error=Password must be at least 6 characters long.`);
    }
    try {
        await fleet_db_1.FleetDb.resetAdminPassword(school.dbName, school.adminEmail, newPassword.trim());
        res.redirect(`/schools/${school.id}?success=Super Admin password reset successfully.`);
    }
    catch (err) {
        console.error('[Password Reset Error]:', err);
        res.redirect(`/schools/${school.id}?error=Failed to reset password.`);
    }
});
// 7. 1-Click Database SQL Backup Download
router.get('/:id/backup-db', (0, permissions_1.requirePermission)(permissions_2.PERMISSIONS.BACKUPS_DOWNLOAD), async (req, res) => {
    const school = await master_db_1.MasterDb.getSchoolById(req.params.id);
    if (!school)
        return res.redirect('/schools');
    try {
        const sqlDump = await fleet_db_1.FleetDb.generateSqlDump(school.dbName, school.name, school.slug);
        const filename = `${school.slug}_backup_${Date.now()}.sql`;
        res.setHeader('Content-Type', 'application/sql');
        res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
        res.send(sqlDump);
    }
    catch (err) {
        console.error('[Backup Error]:', err);
        res.redirect(`/schools/${school.id}?error=Database backup failed: ${encodeURIComponent(err.message)}`);
    }
});
// 8. Update School Configuration & Quotas
router.post('/:id/edit', (0, permissions_1.requirePermission)(permissions_2.PERMISSIONS.SCHOOLS_EDIT), async (req, res) => {
    const school = await master_db_1.MasterDb.getSchoolById(req.params.id);
    if (!school)
        return res.redirect('/schools');
    const { name, adminEmail, customDomain, storageQuotaGb, maxStudents, status } = req.body;
    const allowedStatuses = ['active', 'suspended', 'stopped'];
    const nextStatus = status ? String(status) : school.status;
    if (!allowedStatuses.includes(nextStatus)) {
        return res.redirect(`/schools/${school.id}?error=Invalid status.`);
    }
    const storageQuota = (0, validation_1.validateBoundedInt)(storageQuotaGb, 1, 500);
    if (!storageQuota.valid) {
        return res.redirect(`/schools/${school.id}?error=${encodeURIComponent(`Storage quota: ${storageQuota.error}`)}`);
    }
    const maxStudentsVal = (0, validation_1.validateBoundedInt)(maxStudents, 1, 100000);
    if (!maxStudentsVal.valid) {
        return res.redirect(`/schools/${school.id}?error=${encodeURIComponent(`Max students: ${maxStudentsVal.error}`)}`);
    }
    let cleanDomain;
    if (customDomain) {
        const domainValidation = (0, validation_1.validateDomain)(customDomain);
        if (!domainValidation.valid) {
            return res.redirect(`/schools/${school.id}?error=${encodeURIComponent(domainValidation.error || 'Invalid custom domain.')}`);
        }
        cleanDomain = domainValidation.value;
    }
    try {
        await master_db_1.MasterDb.updateSchool(school.id, {
            name: name ? name.trim() : school.name,
            adminEmail: adminEmail ? adminEmail.trim() : school.adminEmail,
            customDomain: cleanDomain,
            storageQuotaGb: storageQuota.value,
            maxStudents: maxStudentsVal.value,
            status: nextStatus,
            sslStatus: cleanDomain ? 'pending' : school.sslStatus,
        });
        // Also update tenant sch_settings table
        if (name || adminEmail) {
            await fleet_db_1.FleetDb.updateSchoolSettings(school.dbName, name ? name.trim() : school.name, adminEmail ? adminEmail.trim() : school.adminEmail);
        }
        res.redirect(`/schools/${school.id}?success=School configuration updated successfully.`);
    }
    catch (err) {
        console.error('[School Edit Error]:', err);
        res.redirect(`/schools/${school.id}?error=Failed to update configuration.`);
    }
});
// 9. Quick Status Toggle
router.post('/:id/set-status', (0, permissions_1.requirePermission)(permissions_2.PERMISSIONS.SCHOOLS_LIFECYCLE), async (req, res) => {
    const school = await master_db_1.MasterDb.getSchoolById(req.params.id);
    if (!school)
        return res.redirect('/schools');
    const { status } = req.body;
    if (!['active', 'suspended', 'stopped'].includes(status)) {
        return res.redirect(`/schools/${school.id}?error=Invalid status.`);
    }
    if (status === 'active') {
        const ok = await docker_service_1.DockerService.startContainer(school.containerName);
        if (!ok)
            return res.redirect(`/schools/${school.id}?error=Container failed to start.`);
    }
    else if (status === 'stopped') {
        const ok = await docker_service_1.DockerService.stopContainer(school.containerName);
        if (!ok)
            return res.redirect(`/schools/${school.id}?error=Container failed to stop.`);
    }
    await master_db_1.MasterDb.updateSchool(school.id, { status });
    res.redirect(`/schools/${school.id}?success=School status set to ${status}.`);
});
// 10. Lifecycle Actions
router.post('/:id/start', (0, permissions_1.requirePermission)(permissions_2.PERMISSIONS.SCHOOLS_LIFECYCLE), async (req, res) => {
    const school = await master_db_1.MasterDb.getSchoolById(req.params.id);
    if (!school)
        return res.redirect('/schools');
    const ok = await docker_service_1.DockerService.startContainer(school.containerName);
    if (!ok)
        return res.redirect(`/schools/${school.id}?error=Container failed to start.`);
    await master_db_1.MasterDb.updateSchool(school.id, { status: 'active' });
    res.redirect(`/schools/${school.id}?success=Container started successfully.`);
});
router.post('/:id/stop', (0, permissions_1.requirePermission)(permissions_2.PERMISSIONS.SCHOOLS_LIFECYCLE), async (req, res) => {
    const school = await master_db_1.MasterDb.getSchoolById(req.params.id);
    if (!school)
        return res.redirect('/schools');
    const ok = await docker_service_1.DockerService.stopContainer(school.containerName);
    if (!ok)
        return res.redirect(`/schools/${school.id}?error=Container failed to stop.`);
    await master_db_1.MasterDb.updateSchool(school.id, { status: 'stopped' });
    res.redirect(`/schools/${school.id}?success=Container stopped.`);
});
router.post('/:id/restart', (0, permissions_1.requirePermission)(permissions_2.PERMISSIONS.SCHOOLS_LIFECYCLE), async (req, res) => {
    const school = await master_db_1.MasterDb.getSchoolById(req.params.id);
    if (!school)
        return res.redirect('/schools');
    const ok = await docker_service_1.DockerService.restartContainer(school.containerName);
    if (!ok)
        return res.redirect(`/schools/${school.id}?error=Container failed to restart.`);
    res.redirect(`/schools/${school.id}?success=Container restarted successfully.`);
});
router.post('/:id/suspend', (0, permissions_1.requirePermission)(permissions_2.PERMISSIONS.SCHOOLS_LIFECYCLE), async (req, res) => {
    const school = await master_db_1.MasterDb.getSchoolById(req.params.id);
    if (school) {
        await master_db_1.MasterDb.updateSchool(school.id, { status: 'suspended' });
    }
    res.redirect(`/schools/${req.params.id}?success=School suspended. Public traffic blocked.`);
});
router.post('/:id/activate', (0, permissions_1.requirePermission)(permissions_2.PERMISSIONS.SCHOOLS_LIFECYCLE), async (req, res) => {
    const school = await master_db_1.MasterDb.getSchoolById(req.params.id);
    if (school) {
        await master_db_1.MasterDb.updateSchool(school.id, { status: 'active' });
    }
    res.redirect(`/schools/${req.params.id}?success=School reactivated.`);
});
router.post('/:id/delete', (0, permissions_1.requirePermission)(permissions_2.PERMISSIONS.SCHOOLS_PURGE), async (req, res) => {
    const school = await master_db_1.MasterDb.getSchoolById(req.params.id);
    if (school) {
        await docker_service_1.DockerService.removeContainer(school.containerName);
        await master_db_1.MasterDb.deleteSchool(school.id);
    }
    res.redirect('/schools?success=School permanently deleted.');
});
exports.default = router;
