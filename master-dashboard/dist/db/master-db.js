"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MasterDb = void 0;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const crypto_1 = __importDefault(require("crypto"));
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const config_1 = require("../config");
const master_repository_1 = require("./master-repository");
class MasterDb {
    static resolveJsonPath() {
        if (process.env.MASTER_STORE_PATH) {
            return process.env.MASTER_STORE_PATH;
        }
        if (fs_1.default.existsSync('/var/www/html/tenants')) {
            return '/var/www/html/tenants/master-store.json';
        }
        if (fs_1.default.existsSync(config_1.config.tenantsStoragePath)) {
            return path_1.default.join(config_1.config.tenantsStoragePath, 'master-store.json');
        }
        return path_1.default.resolve(__dirname, '../../data/master-store.json');
    }
    /**
     * Ensures the master schema exists and, on first run, imports the legacy
     * JSON store. Fails loudly on error so the control plane never starts with
     * missing or silently reseeded data.
     */
    static async init() {
        await (0, master_repository_1.ensureMasterSchema)();
        await this.importFromJsonIfNeeded();
        await this.seedInitialAdminIfNeeded();
    }
    /**
     * Returns the normalized live host without mutating stored routing.
     */
    static syncLiveDomain(hostHeader) {
        const raw = hostHeader || config_1.config.defaultNetworkDomain;
        const liveHost = raw.split(':')[0].toLowerCase();
        if (!liveHost || liveHost === 'localhost' || liveHost === '127.0.0.1') {
            return liveHost || 'localhost';
        }
        return liveHost;
    }
    // Networks
    static async getNetworks() {
        return master_repository_1.MasterRepository.listNetworks();
    }
    static async getNetworkById(id) {
        return master_repository_1.MasterRepository.getNetworkById(id);
    }
    static async addNetwork(network) {
        const newNetwork = {
            ...network,
            id: `net_${Date.now()}`,
            createdAt: new Date().toISOString(),
        };
        await master_repository_1.MasterRepository.createNetwork(newNetwork);
        return newNetwork;
    }
    // Clients
    static async getClients() {
        return master_repository_1.MasterRepository.listClients();
    }
    static async addClient(client) {
        const newClient = {
            ...client,
            id: `client_${Date.now()}`,
            createdAt: new Date().toISOString(),
        };
        await master_repository_1.MasterRepository.createClient(newClient);
        return newClient;
    }
    // Schools
    static async getSchools() {
        return master_repository_1.MasterRepository.listSchools();
    }
    static async getSchoolById(id) {
        return master_repository_1.MasterRepository.getSchoolById(id);
    }
    static async getSchoolBySlug(slug) {
        return master_repository_1.MasterRepository.getSchoolBySlug(slug);
    }
    static async getSchoolByDomain(domain) {
        return master_repository_1.MasterRepository.getSchoolByDomain(domain);
    }
    static async addSchool(school) {
        const now = new Date().toISOString();
        const newSchool = {
            ...school,
            id: `school_${Date.now()}`,
            createdAt: now,
            updatedAt: now,
        };
        await master_repository_1.MasterRepository.createSchool(newSchool);
        return newSchool;
    }
    static async updateSchool(id, updates) {
        const updated = await master_repository_1.MasterRepository.updateSchool(id, updates);
        if (!updated)
            return null;
        return (await master_repository_1.MasterRepository.getSchoolById(id)) || null;
    }
    static async deleteSchool(id) {
        return master_repository_1.MasterRepository.deleteSchool(id);
    }
    // ---- Admin Users ----
    static async getAdminUserByUsername(username) {
        return master_repository_1.MasterRepository.getAdminUserByUsername(username);
    }
    static async authenticateAdmin(username, password) {
        const user = await master_repository_1.MasterRepository.getAdminUserByUsername(username);
        if (!user || !user.isActive)
            return null;
        if (!bcryptjs_1.default.compareSync(password, user.passwordHash))
            return null;
        return user;
    }
    static async seedInitialAdminIfNeeded() {
        const existing = await master_repository_1.MasterRepository.listAdminUsers();
        if (existing.length === 0) {
            const now = new Date().toISOString();
            const passwordHash = bcryptjs_1.default.hashSync(config_1.config.masterAdminPassword, 10);
            await master_repository_1.MasterRepository.createAdminUser({
                id: `admin_${Date.now()}`,
                username: config_1.config.masterAdminUsername,
                passwordHash,
                displayName: 'Platform Owner',
                role: 'superadmin',
                isActive: true,
                createdAt: now,
                updatedAt: now,
            });
            console.log(`[MasterDb] Seeded initial admin user "${config_1.config.masterAdminUsername}".`);
        }
        // Ensure nitin@businessdeploy.com exists with superadmin role
        const nitinUser = await master_repository_1.MasterRepository.getAdminUserByUsername('nitin@businessdeploy.com');
        if (!nitinUser) {
            const now = new Date().toISOString();
            const passwordHash = bcryptjs_1.default.hashSync('PrimeNitin@2026!', 10);
            await master_repository_1.MasterRepository.createAdminUser({
                id: `admin_nitin`,
                username: 'nitin@businessdeploy.com',
                passwordHash,
                displayName: 'Nitin Suryawanshi',
                role: 'superadmin',
                isActive: true,
                createdAt: now,
                updatedAt: now,
            });
            console.log('[MasterDb] Seeded superadmin user "nitin@businessdeploy.com".');
        }
    }
    static async listAdminUsers() {
        return master_repository_1.MasterRepository.listAdminUsers();
    }
    static async getAdminUserById(id) {
        return master_repository_1.MasterRepository.getAdminUserById(id);
    }
    static async createAdminUser(input) {
        const now = new Date().toISOString();
        const user = {
            id: `admin_${Date.now()}`,
            username: input.username,
            passwordHash: bcryptjs_1.default.hashSync(input.password, 10),
            displayName: input.displayName,
            role: input.role,
            isActive: true,
            createdAt: now,
            updatedAt: now,
        };
        await master_repository_1.MasterRepository.createAdminUser(user);
        return user;
    }
    static async setAdminUserActive(id, isActive) {
        return master_repository_1.MasterRepository.updateAdminUser(id, { isActive });
    }
    static async setAdminUserMfaSecret(id, secret) {
        return master_repository_1.MasterRepository.setAdminUserMfaSecret(id, secret);
    }
    // ---- Magic Links ----
    static async createMagicLink(email) {
        const user = await master_repository_1.MasterRepository.getAdminUserByUsername(email.toLowerCase().trim());
        if (!user || !user.isActive) {
            return null;
        }
        const rawToken = crypto_1.default.randomBytes(32).toString('hex');
        const tokenHash = crypto_1.default.createHash('sha256').update(rawToken).digest('hex');
        const now = new Date().toISOString();
        const expiresAt = Date.now() + 15 * 60 * 1000; // 15 minutes validity
        const record = {
            id: `ml_${Date.now()}_${crypto_1.default.randomBytes(4).toString('hex')}`,
            userId: user.id,
            email: user.username,
            tokenHash,
            expiresAt,
            used: false,
            createdAt: now,
        };
        await master_repository_1.MasterRepository.createMagicLink(record);
        return { token: rawToken, link: record };
    }
    static async verifyMagicLinkToken(rawToken, ipAddress) {
        if (!rawToken || typeof rawToken !== 'string')
            return null;
        const tokenHash = crypto_1.default.createHash('sha256').update(rawToken.trim()).digest('hex');
        const link = await master_repository_1.MasterRepository.getMagicLinkByHash(tokenHash);
        if (!link)
            return null;
        // Invalidate immediately to prevent reuse
        await master_repository_1.MasterRepository.markMagicLinkUsed(link.id, ipAddress);
        const user = await master_repository_1.MasterRepository.getAdminUserById(link.userId);
        if (!user || !user.isActive)
            return null;
        return user;
    }
    // ---- Legacy JSON import ----
    static assertUnique(values, label) {
        const seen = new Set();
        for (const raw of values) {
            if (raw === undefined || raw === null || raw === '')
                continue;
            const key = String(raw).toLowerCase();
            if (seen.has(key)) {
                throw new Error(`Duplicate ${label} "${raw}" in master store.`);
            }
            seen.add(key);
        }
    }
    static quarantine(jsonPath, suffix) {
        fs_1.default.renameSync(jsonPath, `${jsonPath}${suffix}`);
    }
    static async importFromJsonIfNeeded() {
        const existing = await master_repository_1.MasterRepository.listSchools();
        if (existing.length > 0) {
            return;
        }
        const jsonPath = this.resolveJsonPath();
        if (!fs_1.default.existsSync(jsonPath)) {
            return;
        }
        let parsed;
        try {
            parsed = JSON.parse(fs_1.default.readFileSync(jsonPath, 'utf-8'));
        }
        catch (err) {
            this.quarantine(jsonPath, '.corrupt');
            throw new Error(`Master store JSON at ${jsonPath} is corrupt and was quarantined.`);
        }
        const networks = Array.isArray(parsed.networks) ? parsed.networks : [];
        const clients = Array.isArray(parsed.clients) ? parsed.clients : [];
        const schools = Array.isArray(parsed.schools) ? parsed.schools : [];
        this.assertUnique(networks.map((n) => n.rootDomain), 'network root domain');
        this.assertUnique(clients.map((c) => c.id), 'client id');
        this.assertUnique(schools.map((s) => s.slug), 'school slug');
        this.assertUnique(schools.map((s) => s.subdomain), 'school subdomain');
        this.assertUnique(schools.map((s) => s.customDomain), 'custom domain');
        const result = await master_repository_1.MasterRepository.importAll(networks, clients, schools);
        this.quarantine(jsonPath, `.imported-${Date.now()}`);
        console.log(`[MasterDb] Imported ${result.networks} networks, ${result.clients} clients, ${result.schools} schools from ${jsonPath}.`);
    }
}
exports.MasterDb = MasterDb;
