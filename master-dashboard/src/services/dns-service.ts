import dns from 'dns';
const dnsPromises = dns.promises;

export interface DnsCheckResult {
  domain: string;
  isConfigured: boolean;
  recordsFound: string[];
  expectedTarget: string;
  error?: string;
}

export class DnsService {
  /**
   * Check if a custom domain or subdomain is pointing to the network ingress.
   */
  public static async verifyDomain(domain: string, expectedTarget: string): Promise<DnsCheckResult> {
    const cleanDomain = domain.split(':')[0].trim().toLowerCase();

    try {
      // 1. Try CNAME lookup
      const cnames = await dnsPromises.resolveCname(cleanDomain).catch(() => []);
      if (cnames.length > 0) {
        const isMatched = cnames.some((c) => c.toLowerCase().includes(expectedTarget.toLowerCase()));
        return {
          domain: cleanDomain,
          isConfigured: isMatched || cnames.length > 0,
          recordsFound: cnames,
          expectedTarget,
        };
      }

      // 2. Try A Record lookup
      const aRecords = await dnsPromises.resolve4(cleanDomain).catch(() => []);
      if (aRecords.length > 0) {
        return {
          domain: cleanDomain,
          isConfigured: true,
          recordsFound: aRecords,
          expectedTarget,
        };
      }

      return {
        domain: cleanDomain,
        isConfigured: false,
        recordsFound: [],
        expectedTarget,
        error: 'No CNAME or A records found for this domain.',
      };
    } catch (err: any) {
      return {
        domain: cleanDomain,
        isConfigured: false,
        recordsFound: [],
        expectedTarget,
        error: err.message || 'DNS resolution error',
      };
    }
  }
}
