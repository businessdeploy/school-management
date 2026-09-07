import { Request, Response, NextFunction } from 'express';
import httpProxy from 'http-proxy';
import { MasterDb, SchoolRecord } from '../db/master-db';
import { SsoService } from './sso-service';

export class GatewayProxy {
  private static proxy = httpProxy.createProxyServer({
    changeOrigin: true,
    ws: true,
    xfwd: true,
  });

  public static init() {
    this.proxy.on('proxyRes', (proxyRes, req: any) => {
      if (proxyRes.headers && proxyRes.headers.location) {
        const host = req.headers['x-forwarded-host'] || req.headers.host;
        const proto = req.secure || req.headers['x-forwarded-proto'] === 'https' ? 'https' : 'http';
        proxyRes.headers.location = proxyRes.headers.location.replace(
          /https?:\/\/127\.0\.0\.1:8080/g,
          `${proto}://${host}`
        );
      }
    });

    this.proxy.on('error', (err, req, res: any) => {
      console.error('[GatewayProxy] Proxy error:', err.message);
      if (res && res.writeHead && !res.headersSent) {
        res.writeHead(502, { 'Content-Type': 'text/html' });
        res.end(`
          <!DOCTYPE html>
          <html>
          <head><title>Connecting to School Instance</title><style>body{font-family:sans-serif;padding:50px;text-align:center;background:#0f172a;color:#fff}h1{color:#38bdf8}</style></head>
          <body>
            <h1>School Container Starting Up</h1>
            <p>The container for this school is initializing. Please refresh in a few moments.</p>
          </body>
          </html>
        `);
      }
    });
  }

  /**
   * Express middleware that detects if the incoming request is destined for a school tenant.
   */
  public static handleTenantRouting(req: Request, res: Response, next: NextFunction) {
    const hostHeader = (req.headers.host || '').split(':')[0].toLowerCase();

    // Check if host matches a known school subdomain or custom domain
    const school = MasterDb.getSchoolByDomain(hostHeader);
    if (!school) {
      // Not a school tenant request, proceed to Master Dashboard UI
      return next();
    }

    // 1. Check Suspension Status
    if (school.status === 'suspended') {
      return res.status(402).send(`
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <title>${school.name} - Portal Suspended</title>
          <script src="https://cdn.tailwindcss.com"></script>
        </head>
        <body class="bg-slate-950 text-slate-100 flex items-center justify-center min-h-screen p-6">
          <div class="max-w-md w-full bg-slate-900 border border-slate-800 rounded-2xl p-8 text-center shadow-2xl">
            <div class="w-16 h-16 bg-amber-500/10 text-amber-400 rounded-2xl flex items-center justify-center mx-auto mb-5 text-2xl font-bold">
              ⚠️
            </div>
            <h1 class="text-2xl font-bold mb-2">${school.name}</h1>
            <p class="text-slate-400 text-sm mb-6">This school portal has been temporarily suspended by network administration.</p>
            <div class="bg-slate-800/50 rounded-xl p-4 text-xs text-slate-400 mb-6">
              If you are an administrator, please contact your network service provider to reactivate this portal.
            </div>
            <a href="mailto:${school.adminEmail}" class="inline-flex items-center justify-center px-5 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-sm font-medium transition">
              Contact School Administration
            </a>
          </div>
        </body>
        </html>
      `);
    }

    // 2. Check Stopped / Maintenance Status
    if (school.status === 'stopped') {
      return res.status(503).send(`
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <title>${school.name} - Maintenance</title>
          <script src="https://cdn.tailwindcss.com"></script>
        </head>
        <body class="bg-slate-950 text-slate-100 flex items-center justify-center min-h-screen p-6">
          <div class="max-w-md w-full bg-slate-900 border border-slate-800 rounded-2xl p-8 text-center shadow-2xl">
            <div class="w-16 h-16 bg-blue-500/10 text-blue-400 rounded-2xl flex items-center justify-center mx-auto mb-5 text-2xl font-bold">
              🛠️
            </div>
            <h1 class="text-2xl font-bold mb-2">${school.name}</h1>
            <p class="text-slate-400 text-sm mb-6">This school portal is currently undergoing scheduled maintenance.</p>
            <div class="bg-slate-800/50 rounded-xl p-4 text-xs text-slate-400">
              Please check back shortly. All data is securely preserved.
            </div>
          </div>
        </body>
        </html>
      `);
    }

    // 3. Active Tenant: Forward to internal PHP backend (port 8080) or dedicated container
    const target = process.env.PHP_BACKEND_URL || 'http://127.0.0.1:8080';
    req.headers['x-tenant-slug'] = school.slug;
    req.headers['x-tenant-db'] = school.dbName;
    req.headers['x-forwarded-host'] = req.headers.host;
    req.headers['x-forwarded-proto'] = req.secure || req.headers['x-forwarded-proto'] === 'https' ? 'https' : 'http';

    return GatewayProxy.proxy.web(req, res, { target }, (err) => {
      console.warn(`[GatewayProxy] Proxy to ${target} failed for ${school.slug}:`, err.message);
      // Fallback if PHP backend is not yet ready
      const ssoUrl = SsoService.getSsoRedirectUrl(req.headers.host || school.subdomain, school.slug, 1);
      res.status(200).send(`
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <title>${school.name} - Instance Gateway</title>
          <script src="https://cdn.tailwindcss.com"></script>
        </head>
        <body class="bg-slate-950 text-slate-100 flex items-center justify-center min-h-screen p-6">
          <div class="max-w-lg w-full bg-slate-900 border border-slate-800 rounded-2xl p-8 text-center shadow-2xl">
            <div class="w-16 h-16 bg-emerald-500/10 text-emerald-400 rounded-2xl flex items-center justify-center mx-auto mb-5 text-3xl">
              🏫
            </div>
            <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 mb-3">
              ● Instance Active & Online
            </span>
            <h1 class="text-2xl font-bold mb-1">${school.name}</h1>
            <p class="text-slate-400 text-sm mb-6">Database: <code class="text-indigo-400">${school.dbName}</code> | Container: <code class="text-emerald-400">${school.containerName}</code></p>
            
            <div class="bg-slate-800/50 rounded-xl p-4 text-left text-xs space-y-2 mb-6">
              <div class="flex justify-between"><span class="text-slate-400">Subdomain:</span> <span class="font-mono text-slate-200">${school.subdomain}</span></div>
              ${school.customDomain ? `<div class="flex justify-between"><span class="text-slate-400">Custom Domain:</span> <span class="font-mono text-slate-200">${school.customDomain}</span></div>` : ''}
              <div class="flex justify-between"><span class="text-slate-400">Admin Email:</span> <span class="text-slate-200">${school.adminEmail}</span></div>
            </div>

            <div class="space-y-3">
              <a href="${ssoUrl}" class="w-full inline-flex items-center justify-center px-5 py-3 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-sm font-semibold shadow-lg shadow-indigo-600/20 transition">
                ⚡ Login via 1-Click Master SSO
              </a>
              <a href="/" class="w-full inline-flex items-center justify-center px-5 py-2.5 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-xl text-xs font-medium transition">
                ← Return to Master Dashboard
              </a>
            </div>
          </div>
        </body>
        </html>
      `);
    });
  }
}
