"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EasypanelService = void 0;
class EasypanelService {
    static mcpUrl = process.env.EASYPANEL_MCP_URL ||
        'https://server.businessdeploy.com/api/mcp/3a1e21b11d93ac01096f4aa65333261324a7c229ce22c8cd8f0ba34ae6783291';
    static projectName = process.env.EASYPANEL_PROJECT || 'manage';
    static serviceName = process.env.EASYPANEL_SERVICE || 'school-crm';
    static servicePort = parseInt(process.env.EASYPANEL_PORT || '3000', 10);
    /**
     * Automatically registers a domain with Easypanel's Traefik reverse proxy
     * pointing to this service's HTTP port.
     */
    static async registerDomain(host) {
        if (!this.mcpUrl || !host)
            return false;
        const cleanHost = host.trim().toLowerCase();
        try {
            console.log(`[EasypanelService] Registering domain: ${cleanHost}`);
            const res = await fetch(this.mcpUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    Accept: 'application/json, text/event-stream',
                },
                body: JSON.stringify({
                    jsonrpc: '2.0',
                    id: Date.now(),
                    method: 'tools/call',
                    params: {
                        name: 'execute_mutation',
                        arguments: {
                            procedure: 'createDomain',
                            input: {
                                host: cleanHost,
                                https: true,
                                path: '/',
                                wildcard: false,
                                certificateResolver: '',
                                middlewares: [],
                                destinationType: 'service',
                                serviceDestination: {
                                    projectName: this.projectName,
                                    serviceName: this.serviceName,
                                    port: this.servicePort,
                                    protocol: 'http',
                                    path: '/',
                                },
                            },
                        },
                    },
                }),
            });
            const data = await res.json();
            if (data?.error) {
                console.warn(`[EasypanelService] Error registering domain ${cleanHost}:`, data.error);
                return false;
            }
            console.log(`[EasypanelService] Successfully registered domain ${cleanHost}`);
            return true;
        }
        catch (err) {
            console.warn(`[EasypanelService] Failed to register domain ${cleanHost}:`, err.message);
            return false;
        }
    }
}
exports.EasypanelService = EasypanelService;
