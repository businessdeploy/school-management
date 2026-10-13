import fs from 'fs';
import path from 'path';
import bcrypt from 'bcryptjs';
import { config } from '../config';
import { MasterRepository, ensureMasterSchema } from './master-repository';

export interface NetworkRecord {
  id: string;
  name: string;
  rootDomain: string; // e.g. "yournetwork.com" or "localhost:3000"
  isDefault: boolean;
  description?: string;
  createdAt: string;
}

export interface ClientRecord {
  id: string;
  name: string;
  organization: string;
  email: string;
  phone: string;
  plan: 'Starter' | 'Pro' | 'Enterprise';
  status: 'active' | 'suspended';
  createdAt: string;
}

export interface SchoolRecord {
  id: string;
  slug: string; // unique identifier, e.g. "greenwood"
  name: string;
  clientId: string;
  networkId: string;
  subdomain: string; // e.g. "greenwood.yournetwork.com"
  customDomain?: string; // e.g. "portal.greenwoodhigh.edu"
  dbName: string; // e.g. "ss_tenant_greenwood"
  containerName: string; // e.g. "ss_tenant_greenwood"
  adminEmail: string;
  status: 'active' | 'suspended' | 'stopped' | 'provisioning';
  storageQuotaGb: number;
  maxStudents: number;
  port?: number;
  sslStatus: 'active' | 'pending' | 'failed' | 'n/a';
  createdAt: string;
  updatedAt: string;
}

export interface AdminUserRecord {
  id: string;
  username: string;
  passwordHash: string;
  displayName?: string;
  role: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export class MasterDb {
  private static resolveJsonPath(): string {
    if (process.env.MASTER_STORE_PATH) {
      return process.env.MASTER_STORE_PATH;
    }
    if (fs.existsSync('/var/www/html/tenants')) {
      return '/var/www/html/tenants/master-store.json';
    }
    if (fs.existsSync(config.tenantsStoragePath)) {
      return path.join(config.tenantsStoragePath, 'master-store.json');
    }
    return path.resolve(__dirname, '../../data/master-store.json');
  }

  /**
   * Ensures the master schema exists and, on first run, imports the legacy
   * JSON store. Fails loudly on error so the control plane never starts with
   * missing or silently reseeded data.
   */
  public static async init(): Promise<void> {
    await ensureMasterSchema();
    await this.importFromJsonIfNeeded();
    await this.seedInitialAdminIfNeeded();
  }

  /**
   * Returns the normalized live host without mutating stored routing.
   */
  public static syncLiveDomain(hostHeader?: string): string {
    const raw = hostHeader || config.defaultNetworkDomain;
    const liveHost = raw.split(':')[0].toLowerCase();
    if (!liveHost || liveHost === 'localhost' || liveHost === '127.0.0.1') {
      return liveHost || 'localhost';
    }
    return liveHost;
  }

  // Networks
  public static async getNetworks(): Promise<NetworkRecord[]> {
    return MasterRepository.listNetworks();
  }

  public static async getNetworkById(id: string): Promise<NetworkRecord | undefined> {
    return MasterRepository.getNetworkById(id);
  }

  public static async addNetwork(network: Omit<NetworkRecord, 'id' | 'createdAt'>): Promise<NetworkRecord> {
    const newNetwork: NetworkRecord = {
      ...network,
      id: `net_${Date.now()}`,
      createdAt: new Date().toISOString(),
    };
    await MasterRepository.createNetwork(newNetwork);
    return newNetwork;
  }

  // Clients
  public static async getClients(): Promise<ClientRecord[]> {
    return MasterRepository.listClients();
  }

  public static async addClient(client: Omit<ClientRecord, 'id' | 'createdAt'>): Promise<ClientRecord> {
    const newClient: ClientRecord = {
      ...client,
      id: `client_${Date.now()}`,
      createdAt: new Date().toISOString(),
    };
    await MasterRepository.createClient(newClient);
    return newClient;
  }

  // Schools
  public static async getSchools(): Promise<SchoolRecord[]> {
    return MasterRepository.listSchools();
  }

  public static async getSchoolById(id: string): Promise<SchoolRecord | undefined> {
    return MasterRepository.getSchoolById(id);
  }

  public static async getSchoolBySlug(slug: string): Promise<SchoolRecord | undefined> {
    return MasterRepository.getSchoolBySlug(slug);
  }

  public static async getSchoolByDomain(domain: string): Promise<SchoolRecord | undefined> {
    return MasterRepository.getSchoolByDomain(domain);
  }

  public static async addSchool(school: Omit<SchoolRecord, 'id' | 'createdAt' | 'updatedAt'>): Promise<SchoolRecord> {
    const now = new Date().toISOString();
    const newSchool: SchoolRecord = {
      ...school,
      id: `school_${Date.now()}`,
      createdAt: now,
      updatedAt: now,
    };
    await MasterRepository.createSchool(newSchool);
    return newSchool;
  }

  public static async updateSchool(id: string, updates: Partial<SchoolRecord>): Promise<SchoolRecord | null> {
    const updated = await MasterRepository.updateSchool(id, updates);
    if (!updated) return null;
    return (await MasterRepository.getSchoolById(id)) || null;
  }

  public static async deleteSchool(id: string): Promise<boolean> {
    return MasterRepository.deleteSchool(id);
  }

  // ---- Admin Users ----
  public static async getAdminUserByUsername(username: string): Promise<AdminUserRecord | undefined> {
    return MasterRepository.getAdminUserByUsername(username);
  }

  public static async verifyAdminCredentials(
    username: string,
    password: string
  ): Promise<{ username: string; role: string } | null> {
    const user = await MasterRepository.getAdminUserByUsername(username);
    if (!user || !user.isActive) return null;
    if (!bcrypt.compareSync(password, user.passwordHash)) return null;
    return { username: user.username, role: user.role };
  }

  private static async seedInitialAdminIfNeeded(): Promise<void> {
    const existing = await MasterRepository.listAdminUsers();
    if (existing.length > 0) return;

    const now = new Date().toISOString();
    const passwordHash = bcrypt.hashSync(config.masterAdminPassword, 10);
    await MasterRepository.createAdminUser({
      id: `admin_${Date.now()}`,
      username: config.masterAdminUsername,
      passwordHash,
      displayName: 'Platform Owner',
      role: 'superadmin',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    });
    console.log(`[MasterDb] Seeded initial admin user "${config.masterAdminUsername}".`);
  }

  // ---- Legacy JSON import ----

  private static assertUnique(values: any[], label: string): void {
    const seen = new Set<string>();
    for (const raw of values) {
      if (raw === undefined || raw === null || raw === '') continue;
      const key = String(raw).toLowerCase();
      if (seen.has(key)) {
        throw new Error(`Duplicate ${label} "${raw}" in master store.`);
      }
      seen.add(key);
    }
  }

  private static quarantine(jsonPath: string, suffix: string): void {
    fs.renameSync(jsonPath, `${jsonPath}${suffix}`);
  }

  private static async importFromJsonIfNeeded(): Promise<void> {
    const existing = await MasterRepository.listSchools();
    if (existing.length > 0) {
      return;
    }

    const jsonPath = this.resolveJsonPath();
    if (!fs.existsSync(jsonPath)) {
      return;
    }

    let parsed: any;
    try {
      parsed = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
    } catch (err) {
      this.quarantine(jsonPath, '.corrupt');
      throw new Error(`Master store JSON at ${jsonPath} is corrupt and was quarantined.`);
    }

    const networks: NetworkRecord[] = Array.isArray(parsed.networks) ? parsed.networks : [];
    const clients: ClientRecord[] = Array.isArray(parsed.clients) ? parsed.clients : [];
    const schools: SchoolRecord[] = Array.isArray(parsed.schools) ? parsed.schools : [];

    this.assertUnique(networks.map((n) => n.rootDomain), 'network root domain');
    this.assertUnique(clients.map((c) => c.id), 'client id');
    this.assertUnique(schools.map((s) => s.slug), 'school slug');
    this.assertUnique(schools.map((s) => s.subdomain), 'school subdomain');
    this.assertUnique(schools.map((s) => s.customDomain), 'custom domain');

    const result = await MasterRepository.importAll(networks, clients, schools);

    this.quarantine(jsonPath, `.imported-${Date.now()}`);
    console.log(
      `[MasterDb] Imported ${result.networks} networks, ${result.clients} clients, ${result.schools} schools from ${jsonPath}.`
    );
  }
}
