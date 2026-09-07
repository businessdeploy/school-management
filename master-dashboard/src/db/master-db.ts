import fs from 'fs';
import path from 'path';
import { config } from '../config';

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

export interface MasterStoreData {
  networks: NetworkRecord[];
  clients: ClientRecord[];
  schools: SchoolRecord[];
}

export class MasterDb {
  private static dataFilePath = path.resolve(__dirname, '../../data/master-store.json');
  private static data: MasterStoreData = {
    networks: [],
    clients: [],
    schools: [],
  };

  private static resolveDataFilePath(): string {
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

  public static init() {
    this.dataFilePath = this.resolveDataFilePath();
    console.log('[MasterDb] Initialized store at:', this.dataFilePath);
    const dataDir = path.dirname(this.dataFilePath);
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }

    if (fs.existsSync(this.dataFilePath)) {
      try {
        const raw = fs.readFileSync(this.dataFilePath, 'utf-8');
        this.data = JSON.parse(raw);
      } catch (err) {
        console.error('Error reading master-store.json, creating initial store:', err);
        this.seedDefaults();
      }
    } else {
      this.seedDefaults();
    }

    // Auto-migrate domain if rootDomain or school subdomains still point to localhost
    try {
      let modified = false;
      const targetRoot = config.defaultNetworkDomain;
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
    } catch (migErr) {
      console.warn('[MasterDb] Domain auto-migration notice:', migErr);
    }
  }

  /**
   * Synchronize the currently active live domain with the fleet network and school subdomains.
   */
  public static syncLiveDomain(hostHeader?: string): string {
    const raw = hostHeader || config.defaultNetworkDomain;
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

  private static seedDefaults() {
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

  private static save() {
    try {
      fs.writeFileSync(this.dataFilePath, JSON.stringify(this.data, null, 2), 'utf-8');
    } catch (err) {
      console.error('Error saving master-store.json:', err);
    }
  }

  // Networks
  public static getNetworks(): NetworkRecord[] {
    return this.data.networks;
  }

  public static getNetworkById(id: string): NetworkRecord | undefined {
    return this.data.networks.find((n) => n.id === id);
  }

  public static addNetwork(network: Omit<NetworkRecord, 'id' | 'createdAt'>): NetworkRecord {
    const newNetwork: NetworkRecord = {
      ...network,
      id: `net_${Date.now()}`,
      createdAt: new Date().toISOString(),
    };
    this.data.networks.push(newNetwork);
    this.save();
    return newNetwork;
  }

  // Clients
  public static getClients(): ClientRecord[] {
    return this.data.clients;
  }

  public static addClient(client: Omit<ClientRecord, 'id' | 'createdAt'>): ClientRecord {
    const newClient: ClientRecord = {
      ...client,
      id: `client_${Date.now()}`,
      createdAt: new Date().toISOString(),
    };
    this.data.clients.push(newClient);
    this.save();
    return newClient;
  }

  // Schools
  public static getSchools(): SchoolRecord[] {
    return this.data.schools;
  }

  public static getSchoolById(id: string): SchoolRecord | undefined {
    return this.data.schools.find((s) => s.id === id);
  }

  public static getSchoolBySlug(slug: string): SchoolRecord | undefined {
    return this.data.schools.find((s) => s.slug.toLowerCase() === slug.toLowerCase());
  }

  public static getSchoolByDomain(domain: string): SchoolRecord | undefined {
    const cleanDomain = domain.split(':')[0].toLowerCase();
    return this.data.schools.find((s) => {
      const sub = s.subdomain?.split(':')[0].toLowerCase();
      const custom = s.customDomain?.split(':')[0].toLowerCase();
      return sub === cleanDomain || custom === cleanDomain;
    });
  }

  public static addSchool(school: Omit<SchoolRecord, 'id' | 'createdAt' | 'updatedAt'>): SchoolRecord {
    const newSchool: SchoolRecord = {
      ...school,
      id: `school_${Date.now()}`,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    this.data.schools.push(newSchool);
    this.save();
    return newSchool;
  }

  public static updateSchool(id: string, updates: Partial<SchoolRecord>): SchoolRecord | null {
    const idx = this.data.schools.findIndex((s) => s.id === id);
    if (idx === -1) return null;
    this.data.schools[idx] = {
      ...this.data.schools[idx],
      ...updates,
      updatedAt: new Date().toISOString(),
    };
    this.save();
    return this.data.schools[idx];
  }

  public static deleteSchool(id: string): boolean {
    const idx = this.data.schools.findIndex((s) => s.id === id);
    if (idx === -1) return false;
    this.data.schools.splice(idx, 1);
    this.save();
    return true;
  }
}
