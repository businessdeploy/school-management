import express, { Request, Response } from 'express';
import session from 'express-session';
import path from 'path';
import crypto from 'crypto';
import { config, validateConfig } from './config';
import { MasterDb } from './db/master-db';
import { FleetDb } from './db/fleet-db';
import { DbSessionStore } from './db/session-store';
import { DockerService } from './services/docker-service';
import { GatewayProxy } from './services/gateway-proxy';
import { DataAggregator } from './services/data-aggregator';
import { OperationsService } from './services/operations-service';

import authRoutes, { requireAuth } from './routes/auth-routes';
import { csrfProtection } from './middleware/csrf';
import { requirePermission } from './middleware/permissions';
import { PERMISSIONS } from './permissions';
import schoolRoutes from './routes/school-routes';
import analyticsRoutes from './routes/analytics-routes';
import networkRoutes from './routes/network-routes';
import userRoutes from './routes/user-routes';
import caddyRoutes from './routes/caddy-routes';

import fs from 'fs';

validateConfig();

const app = express();
app.set('trust proxy', 1);

let lastError: any = null;

// 1. Initialize Subsystems
DockerService.init();
GatewayProxy.init();

// 2. View Engine (EJS)
const viewsPath = fs.existsSync(path.join(__dirname, 'views'))
  ? path.join(__dirname, 'views')
  : path.resolve(__dirname, '../src/views');
app.set('views', viewsPath);
app.set('view engine', 'ejs');

// 3. Public Caddy On-Demand TLS Endpoint & Diagnostics (Must be before tenant gateway check)
app.use('/api/v1/domains', caddyRoutes);

app.get('/api/v1/health-diag', async (req: Request, res: Response) => {
  let dbStatus = 'ok';
  let dbError: string | null = null;
  try {
    const test = await FleetDb.executeQuery(config.fleetDb.masterDatabase, 'SELECT 1 as test');
  } catch (err: any) {
    dbStatus = 'error';
    dbError = err?.message || String(err);
  }

  let sessionTable = 'unknown';
  try {
    const rows = await FleetDb.executeQuery(config.fleetDb.masterDatabase, 'SHOW TABLES LIKE "sessions"');
    sessionTable = rows && rows.length > 0 ? 'exists' : 'missing';
  } catch (err: any) {
    sessionTable = `error: ${err.message}`;
  }

  let phpPort8080 = 'checking';
  try {
    const http = await import('http');
    await new Promise((resolve) => {
      const ping = http.get('http://127.0.0.1:8080', { timeout: 2000 }, (resp) => {
        phpPort8080 = `alive_status_${resp.statusCode}`;
        resolve(true);
      });
      ping.on('error', (e) => {
        phpPort8080 = `unreachable: ${e.message}`;
        resolve(false);
      });
    });
  } catch (e: any) {
    phpPort8080 = `error: ${e.message}`;
  }

  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    viewsPath,
    viewsExist: fs.existsSync(viewsPath),
    loginEjs: fs.existsSync(path.join(viewsPath, 'login.ejs')),
    dbStatus,
    dbError,
    sessionTable,
    phpPort8080,
    lastError,
  });
});

// 4. Intelligent Tenant Gateway Router (Must be BEFORE body parsers to preserve stream for proxying!)
app.use(GatewayProxy.handleTenantRouting);

// 5. Static Assets & Body Parsers (Only needed for Master Dashboard)
app.use(express.static(path.join(__dirname, '../public')));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 6. Session Middleware
app.use(
  session({
    name: 'master.sid',
    secret: config.sessionSecret,
    resave: false,
    saveUninitialized: false,
    store: new DbSessionStore(),
    cookie: {
      httpOnly: true,
      sameSite: 'lax',
      secure: config.env === 'production',
      maxAge: 86400000, // 24 hours
    },
  })
);

// 7. Master Auth Routes
app.use('/auth', authRoutes);

// 8. Master Dashboard Protected Routes
app.use((req, res, next) => {
  res.locals.user = (req.session as any)?.user || null;
  res.locals.currentPath = req.path;
  next();
});

// Overview Dashboard
app.get('/', requireAuth, async (req: Request, res: Response) => {
  const telemetry = await DataAggregator.getFleetTelemetry();
  const schools = await MasterDb.getSchools();
  const networks = await MasterDb.getNetworks();
  const clients = await MasterDb.getClients();

  res.render('dashboard', {
    pageTitle: 'Master Fleet Control Plane',
    telemetry,
    schools,
    networks,
    clients,
  });
});

app.use('/schools', requireAuth, csrfProtection, schoolRoutes);
app.use('/master-data', requireAuth, csrfProtection, analyticsRoutes);
app.use('/networks', requireAuth, csrfProtection, networkRoutes);
app.use('/users', requireAuth, csrfProtection, requirePermission(PERMISSIONS.USERS_MANAGE), userRoutes);

// 404 Fallback
app.use((req: Request, res: Response) => {
  res.status(404).send(`
    <!DOCTYPE html>
    <html><head><title>Page Not Found</title><script src="https://cdn.tailwindcss.com"></script></head>
    <body class="bg-slate-950 text-white flex items-center justify-center min-h-screen">
      <div class="text-center">
        <h1 class="text-6xl font-bold text-indigo-500 mb-4">404</h1>
        <p class="text-slate-400 mb-6">The requested Master Control resource does not exist.</p>
        <a href="/" class="px-5 py-2.5 bg-indigo-600 rounded-xl text-sm font-semibold">Back to Dashboard</a>
      </div>
    </body></html>
  `);
});

// Global Error Handler Middleware
app.use((err: any, req: Request, res: Response, next: any) => {
  const referenceId = crypto.randomUUID();
  console.error(`[MASTER CONTROL PLANE ERROR] ref=${referenceId}:`, err);
  lastError = {
    ref: referenceId,
    message: err?.message || String(err),
    stack: err?.stack,
    code: err?.code,
    name: err?.name,
    path: req.originalUrl || req.path,
    method: req.method,
    host: req.headers.host,
    time: new Date().toISOString(),
  };
  if (res.headersSent) {
    return next(err);
  }
  res.status(500).send(`
    <!DOCTYPE html>
    <html class="dark">
      <head>
        <title>Control Plane Error</title>
        <script src="https://cdn.tailwindcss.com"></script>
      </head>
      <body class="bg-slate-950 text-slate-100 p-8 flex items-center justify-center min-h-screen">
        <div class="max-w-2xl w-full bg-slate-900 border border-rose-500/30 rounded-2xl p-6 shadow-2xl">
          <div class="flex items-center space-x-3 mb-4">
            <span class="text-2xl">⚠️</span>
            <h2 class="text-lg font-bold text-rose-400">Master Orchestrator Error</h2>
          </div>
          <p class="text-sm text-slate-300 mb-3">Something went wrong while handling this request.</p>
          <p class="text-xs text-slate-500 mb-6">Reference ID: <code class="font-mono">${referenceId}</code></p>
          <div class="mt-6">
            <a href="/schools" class="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 rounded-xl text-xs font-semibold text-white transition">← Return to Schools</a>
          </div>
        </div>
      </body>
    </html>
  `);
});

// Start Server
(async () => {
  try {
    await MasterDb.init();
    try {
      const recovered = await OperationsService.recoverStaleOperations();
      if (recovered > 0) {
        console.log(`[Reconciliation] Marked ${recovered} stale operation(s) as failed.`);
      }
    } catch (err: any) {
      console.warn('[Reconciliation] Stale operation recovery skipped:', err.message);
    }

    setInterval(() => {
      OperationsService.recoverStaleOperations().catch(() => {});
    }, 5 * 60 * 1000);

    app.listen(config.port, config.host, () => {
      console.log(`=======================================================`);
      console.log(`🚀 Smart School Master Control Plane is Online!`);
      console.log(`🌐 Dashboard URL: http://${config.host}:${config.port}`);
      console.log(`=======================================================`);
    });
  } catch (err: any) {
    console.error('[MasterDb] Failed to initialize master store:', err);
    process.exit(1);
  }
})();
