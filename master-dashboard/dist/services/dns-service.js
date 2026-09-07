"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DnsService = void 0;
const dns_1 = __importDefault(require("dns"));
const dnsPromises = dns_1.default.promises;
class DnsService {
    /**
     * Check if a custom domain or subdomain is pointing to the network ingress.
     */
    static async verifyDomain(domain, expectedTarget) {
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
        }
        catch (err) {
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
exports.DnsService = DnsService;
