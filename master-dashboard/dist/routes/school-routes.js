"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const master_db_1 = require("../db/master-db");
const seed_installer_1 = require("../db/seed-installer");
const fleet_db_1 = require("../db/fleet-db");
const docker_service_1 = require("../services/docker-service");
const sso_service_1 = require("../services/sso-service");
const easypanel_service_1 = require("../services/easypanel-service");
const config_1 = require("../config");
const router = (0, express_1.Router)();
// 1. List Schools
router.get('/', async (req, res) => {
    const hostHeader = (req.headers['x-forwarded-host'] || req.headers.host);
    const currentHost = master_db_1.MasterDb.syncLiveDomain(hostHeader);
    const schools = master_db_1.MasterDb.getSchools();
    const clients = master_db_1.MasterDb.getClients();
    const networks = master_db_1.MasterDb.getNetworks();
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
router.get('/new', (req, res) => {
    const hostHeader = (req.headers['x-forwarded-host'] || req.headers.host);
    master_db_1.MasterDb.syncLiveDomain(hostHeader);
    const clients = master_db_1.MasterDb.getClients();
    const networks = master_db_1.MasterDb.getNetworks();
    res.render('school-create', {
        pageTitle: 'Instant School Onboarding Wizard',
        clients,
        networks,
        error: null,
    });
});
// 3. Create School (End-to-End Onboarding)
router.post('/create', async (req, res) => {
    const { name, slug, clientId, networkId, customDomain, adminEmail, adminPassword, currencySymbol, timezone, storageQuotaGb, maxStudents, } = req.body;
    // Clean slug: lowercase alphanumeric and hyphens only
    const cleanSlug = (slug || '')
        .toLowerCase()
        .trim()
        .replace(/[^a-z0-9-]/g, '');
    if (!cleanSlug || !name || !adminEmail) {
        const clients = master_db_1.MasterDb.getClients();
        const networks = master_db_1.MasterDb.getNetworks();
        return res.render('school-create', {
            pageTitle: 'Instant School Onboarding Wizard',
            clients,
            networks,
            error: 'School Name, Subdomain Slug, and Admin Email are required.',
        });
    }
    // Check uniqueness
    if (master_db_1.MasterDb.getSchoolBySlug(cleanSlug)) {
        const clients = master_db_1.MasterDb.getClients();
        const networks = master_db_1.MasterDb.getNetworks();
        return res.render('school-create', {
            pageTitle: 'Instant School Onboarding Wizard',
            clients,
            networks,
            error: `Slug "${cleanSlug}" is already taken. Please choose a different subdomain slug.`,
        });
    }
    const network = master_db_1.MasterDb.getNetworkById(networkId) || master_db_1.MasterDb.getNetworks()[0];
    const subdomain = `${cleanSlug}.${network.rootDomain}`;
    const dbName = `${config_1.config.fleetDb.databasePrefix}${cleanSlug}`;
    const containerName = `ss_tenant_${cleanSlug}`;
    try {
        // 1. Save record in master database with status 'provisioning'
        const newSchool = master_db_1.MasterDb.addSchool({
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
        await seed_installer_1.SeedInstaller.provisionTenantDatabase({
            slug: cleanSlug,
            name,
            domain: customDomain || subdomain,
            adminEmail,
            adminPassword: adminPassword || 'Admin@123456',
            currencySymbol: currencySymbol || '$',
            timezone: timezone || 'UTC',
        });
        // 3. Launch isolated container
        await docker_service_1.DockerService.launchTenantContainer({
            slug: cleanSlug,
            containerName,
            dbName,
            domain: customDomain || subdomain,
            ramLimitMb: 512,
        });
        // 4. Register Traefik domain in Easypanel for instant live access
        await easypanel_service_1.EasypanelService.registerDomain(subdomain);
        if (customDomain) {
            await easypanel_service_1.EasypanelService.registerDomain(customDomain);
        }
        // 5. Update status to active
        master_db_1.MasterDb.updateSchool(newSchool.id, { status: 'active' });
        res.redirect(`/schools/${newSchool.id}`);
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
        const school = master_db_1.MasterDb.getSchoolById(req.params.id);
        if (!school)
            return res.redirect('/schools');
        const client = master_db_1.MasterDb.getClients().find((c) => c.id === school.clientId) || {
            id: school.clientId || 'client_default',
            name: 'Direct Client',
            organization: school.name,
            email: school.adminEmail,
            phone: '',
            plan: 'Starter',
            status: 'active',
            createdAt: school.createdAt,
        };
        const network = master_db_1.MasterDb.getNetworks().find((n) => n.id === school.networkId) || {
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
router.get('/:id/sso-login', (req, res) => {
    const school = master_db_1.MasterDb.getSchoolById(req.params.id);
    if (!school)
        return res.redirect('/schools');
    const targetDomain = school.customDomain || school.subdomain;
    const redirectUrl = sso_service_1.SsoService.getSsoRedirectUrl(targetDomain, school.slug, 1);
    console.log(`[Master SSO] Generating 1-click login for ${school.name} -> ${redirectUrl}`);
    res.redirect(redirectUrl);
});
// 6. Direct Super Admin Password Reset
router.post('/:id/reset-password', async (req, res) => {
    const school = master_db_1.MasterDb.getSchoolById(req.params.id);
    if (!school)
        return res.redirect('/schools');
    const { newPassword } = req.body;
    if (!newPassword || newPassword.trim().length < 6) {
        return res.redirect(`/schools/${school.id}?error=Password must be at least 6 characters long.`);
    }
    try {
        await fleet_db_1.FleetDb.resetAdminPassword(school.dbName, school.adminEmail, newPassword.trim());
        res.redirect(`/schools/${school.id}?success=Super Admin password successfully reset to "${newPassword.trim()}".`);
    }
    catch (err) {
        console.error('[Password Reset Error]:', err);
        res.redirect(`/schools/${school.id}?error=Failed to reset password: ${encodeURIComponent(err.message)}`);
    }
});
// 7. 1-Click Database SQL Backup Download
router.get('/:id/backup-db', async (req, res) => {
    const school = master_db_1.MasterDb.getSchoolById(req.params.id);
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
router.post('/:id/edit', async (req, res) => {
    const school = master_db_1.MasterDb.getSchoolById(req.params.id);
    if (!school)
        return res.redirect('/schools');
    const { name, adminEmail, customDomain, storageQuotaGb, maxStudents, status } = req.body;
    try {
        const cleanDomain = customDomain ? customDomain.trim().toLowerCase().replace(/^https?:\/\//, '').replace(/\/$/, '') : undefined;
        master_db_1.MasterDb.updateSchool(school.id, {
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
            await fleet_db_1.FleetDb.updateSchoolSettings(school.dbName, name ? name.trim() : school.name, adminEmail ? adminEmail.trim() : school.adminEmail);
        }
        res.redirect(`/schools/${school.id}?success=School configuration updated successfully.`);
    }
    catch (err) {
        console.error('[School Edit Error]:', err);
        res.redirect(`/schools/${school.id}?error=Failed to update configuration: ${encodeURIComponent(err.message)}`);
    }
});
// 9. Quick Status Toggle
router.post('/:id/set-status', async (req, res) => {
    const school = master_db_1.MasterDb.getSchoolById(req.params.id);
    if (!school)
        return res.redirect('/schools');
    const { status } = req.body;
    if (['active', 'suspended', 'stopped'].includes(status)) {
        master_db_1.MasterDb.updateSchool(school.id, { status });
        if (status === 'active') {
            await docker_service_1.DockerService.startContainer(school.containerName);
        }
        else if (status === 'stopped') {
            await docker_service_1.DockerService.stopContainer(school.containerName);
        }
        res.redirect(`/schools/${school.id}?success=School status set to ${status}.`);
    }
    else {
        res.redirect(`/schools/${school.id}?error=Invalid status.`);
    }
});
// 10. Lifecycle Actions
router.post('/:id/start', async (req, res) => {
    const school = master_db_1.MasterDb.getSchoolById(req.params.id);
    if (school) {
        await docker_service_1.DockerService.startContainer(school.containerName);
        master_db_1.MasterDb.updateSchool(school.id, { status: 'active' });
    }
    res.redirect(`/schools/${req.params.id}?success=Container started successfully.`);
});
router.post('/:id/stop', async (req, res) => {
    const school = master_db_1.MasterDb.getSchoolById(req.params.id);
    if (school) {
        await docker_service_1.DockerService.stopContainer(school.containerName);
        master_db_1.MasterDb.updateSchool(school.id, { status: 'stopped' });
    }
    res.redirect(`/schools/${req.params.id}?success=Container stopped.`);
});
router.post('/:id/restart', async (req, res) => {
    const school = master_db_1.MasterDb.getSchoolById(req.params.id);
    if (school) {
        await docker_service_1.DockerService.restartContainer(school.containerName);
    }
    res.redirect(`/schools/${req.params.id}?success=Container restarted successfully.`);
});
router.post('/:id/suspend', (req, res) => {
    const school = master_db_1.MasterDb.getSchoolById(req.params.id);
    if (school) {
        master_db_1.MasterDb.updateSchool(school.id, { status: 'suspended' });
    }
    res.redirect(`/schools/${req.params.id}?success=School suspended. Public traffic blocked.`);
});
router.post('/:id/activate', (req, res) => {
    const school = master_db_1.MasterDb.getSchoolById(req.params.id);
    if (school) {
        master_db_1.MasterDb.updateSchool(school.id, { status: 'active' });
    }
    res.redirect(`/schools/${req.params.id}?success=School reactivated.`);
});
router.post('/:id/delete', async (req, res) => {
    const school = master_db_1.MasterDb.getSchoolById(req.params.id);
    if (school) {
        await docker_service_1.DockerService.removeContainer(school.containerName);
        master_db_1.MasterDb.deleteSchool(school.id);
    }
    res.redirect('/schools?success=School permanently deleted.');
});
exports.default = router;
