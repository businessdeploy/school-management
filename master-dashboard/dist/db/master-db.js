"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MasterDb = void 0;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const config_1 = require("../config");
class MasterDb {
    static dataFilePath = path_1.default.resolve(__dirname, '../../data/master-store.json');
    static data = {
        networks: [],
        clients: [],
        schools: [],
    };
    static resolveDataFilePath() {
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
    static init() {
        this.dataFilePath = this.resolveDataFilePath();
        console.log('[MasterDb] Initialized store at:', this.dataFilePath);
        const dataDir = path_1.default.dirname(this.dataFilePath);
        if (!fs_1.default.existsSync(dataDir)) {
            fs_1.default.mkdirSync(dataDir, { recursive: true });
        }
        if (fs_1.default.existsSync(this.dataFilePath)) {
            try {
                const raw = fs_1.default.readFileSync(this.dataFilePath, 'utf-8');
                this.data = JSON.parse(raw);
            }
            catch (err) {
                console.error('Error reading master-store.json, creating initial store:', err);
                this.seedDefaults();
            }
        }
        else {
            this.seedDefaults();
        }
        // Auto-migrate domain if rootDomain or school subdomains still point to localhost
        try {
            let modified = false;
            const targetRoot = config_1.config.defaultNetworkDomain;
            const defaultNet = this.data.networks.find((n) => n.id === 'net_default');
            if (defaultNet && (defaultNet.rootDomain === 'localhost' || defaultNet.rootDomain.includes('localhost'))) {
                defaultNet.rootDomain = targetRoot;
                modified = true;
            }
            for (const school of this.data.schools) {
                if (school.subdomain && (school.subdomain.includes('localhost') || !school.subdomain.includes('.'))) {
                    school.subdomain = `${school.slug}.${targetRoot}`;
                    modified = true;
                }
            }
            if (modified) {
                this.save();
                console.log(`[MasterDb] Auto-migrated school and network domains to live host: ${targetRoot}`);
            }
        }
        catch (migErr) {
            console.warn('[MasterDb] Domain auto-migration notice:', migErr);
        }
    }
    /**
     * Synchronize the currently active live domain with the fleet network and school subdomains.
     */
    static syncLiveDomain(hostHeader) {
        const raw = hostHeader || config_1.config.defaultNetworkDomain;
        const liveHost = raw.split(':')[0].toLowerCase();
        if (!liveHost || liveHost === 'localhost' || liveHost === '127.0.0.1') {
            return liveHost || 'localhost';
        }
        let modified = false;
        const defaultNet = this.data.networks.find((n) => n.id === 'net_default');
        if (defaultNet && defaultNet.rootDomain !== liveHost) {
            console.log(`[MasterDb] Syncing default network domain to live host: ${defaultNet.rootDomain} -> ${liveHost}`);
            defaultNet.rootDomain = liveHost;
            modified = true;
        }
        for (const school of this.data.schools) {
            if (school.subdomain && (school.subdomain.includes('localhost') || !school.subdomain.endsWith(`.${liveHost}`))) {
                school.subdomain = `${school.slug}.${liveHost}`;
                modified = true;
            }
        }
        if (modified) {
            this.save();
            console.log(`[MasterDb] Synchronized ${this.data.schools.length} schools to live domain: *.${liveHost}`);
        }
        return liveHost;
    }
    static seedDefaults() {
        this.data = {
            networks: [
                {
                    id: 'net_default',
                    name: 'Primary Network',
                    rootDomain: 'localhost',
                    isDefault: true,
                    description: 'Default master network for local & standard school portals',
                    createdAt: new Date().toISOString(),
                },
                {
                    id: 'net_apex_group',
                    name: 'Apex Educational Group',
                    rootDomain: 'apexschools.net',
                    isDefault: false,
                    description: 'Dedicated white-label network for Apex partner institutions',
                    createdAt: new Date().toISOString(),
                },
            ],
            clients: [
                {
                    id: 'client_demo',
                    name: 'Dr. Arthur Pendelton',
                    organization: 'Apex Educational Foundation',
                    email: 'admin@apexschools.net',
                    phone: '+1 555-0199',
                    plan: 'Enterprise',
                    status: 'active',
                    createdAt: new Date().toISOString(),
                },
            ],
            schools: [
                {
                    id: 'school_sample_1',
                    slug: 'greenwood',
                    name: 'Greenwood International High',
                    clientId: 'client_demo',
                    networkId: 'net_default',
                    subdomain: 'greenwood.localhost',
                    customDomain: 'portal.greenwoodhigh.edu',
                    dbName: 'ss_tenant_greenwood',
                    containerName: 'ss_tenant_greenwood',
                    adminEmail: 'principal@greenwoodhigh.edu',
                    status: 'active',
                    storageQuotaGb: 20,
                    maxStudents: 2500,
                    sslStatus: 'active',
                    createdAt: new Date(Date.now() - 86400000 * 5).toISOString(),
                    updatedAt: new Date().toISOString(),
                },
                {
                    id: 'school_sample_2',
                    slug: 'dps',
                    name: 'Delhi Public School Campus',
                    clientId: 'client_demo',
                    networkId: 'net_default',
                    subdomain: 'dps.localhost',
                    dbName: 'ss_tenant_dps',
                    containerName: 'ss_tenant_dps',
                    adminEmail: 'admin@dpscampus.org',
                    status: 'active',
                    storageQuotaGb: 10,
                    maxStudents: 1200,
                    sslStatus: 'active',
                    createdAt: new Date(Date.now() - 86400000 * 2).toISOString(),
                    updatedAt: new Date().toISOString(),
                },
            ],
        };
        this.save();
    }
    static save() {
        try {
            fs_1.default.writeFileSync(this.dataFilePath, JSON.stringify(this.data, null, 2), 'utf-8');
        }
        catch (err) {
            console.error('Error saving master-store.json:', err);
        }
    }
    // Networks
    static getNetworks() {
        return this.data.networks;
    }
    static getNetworkById(id) {
        return this.data.networks.find((n) => n.id === id);
    }
    static addNetwork(network) {
        const newNetwork = {
            ...network,
            id: `net_${Date.now()}`,
            createdAt: new Date().toISOString(),
        };
        this.data.networks.push(newNetwork);
        this.save();
        return newNetwork;
    }
    // Clients
    static getClients() {
        return this.data.clients;
    }
    static addClient(client) {
        const newClient = {
            ...client,
            id: `client_${Date.now()}`,
            createdAt: new Date().toISOString(),
        };
        this.data.clients.push(newClient);
        this.save();
        return newClient;
    }
    // Schools
    static getSchools() {
        return this.data.schools;
    }
    static getSchoolById(id) {
        return this.data.schools.find((s) => s.id === id);
    }
    static getSchoolBySlug(slug) {
        return this.data.schools.find((s) => s.slug.toLowerCase() === slug.toLowerCase());
    }
    static getSchoolByDomain(domain) {
        const cleanDomain = domain.split(':')[0].toLowerCase();
        return this.data.schools.find((s) => {
            const sub = s.subdomain?.split(':')[0].toLowerCase();
            const custom = s.customDomain?.split(':')[0].toLowerCase();
            return sub === cleanDomain || custom === cleanDomain;
        });
    }
    static addSchool(school) {
        const newSchool = {
            ...school,
            id: `school_${Date.now()}`,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
        };
        this.data.schools.push(newSchool);
        this.save();
        return newSchool;
    }
    static updateSchool(id, updates) {
        const idx = this.data.schools.findIndex((s) => s.id === id);
        if (idx === -1)
            return null;
        this.data.schools[idx] = {
            ...this.data.schools[idx],
            ...updates,
            updatedAt: new Date().toISOString(),
        };
        this.save();
        return this.data.schools[idx];
    }
    static deleteSchool(id) {
        const idx = this.data.schools.findIndex((s) => s.id === id);
        if (idx === -1)
            return false;
        this.data.schools.splice(idx, 1);
        this.save();
        return true;
    }
}
exports.MasterDb = MasterDb;
