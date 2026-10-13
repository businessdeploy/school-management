import express, { Request, Response } from 'express';
import session from 'express-session';
import path from 'path';
import crypto from 'crypto';
import { config, validateConfig } from './config';
import { MasterDb } from './db/master-db';
import { DbSessionStore } from './db/session-store';
import { DockerService } from './services/docker-service';
import { GatewayProxy } from './services/gateway-proxy';
import { DataAggregator } from './services/data-aggregator';

import authRoutes, { requireAuth } from './routes/auth-routes';
import { csrfProtection } from './middleware/csrf';
import schoolRoutes from './routes/school-routes';
import analyticsRoutes from './routes/analytics-routes';
import networkRoutes from './routes/network-routes';
import caddyRoutes from './routes/caddy-routes';

import fs from 'fs';

validateConfig();

const app = express();

// 1. Initialize Subsystems
DockerService.init();
GatewayProxy.init();

// 2. View Engine (EJS)
const viewsPath = fs.existsSync(path.join(__dirname, 'views'))
  ? path.join(__dirname, 'views')
  : path.resolve(__dirname, '../src/views');
app.set('views', viewsPath);
app.set('view engine', 'ejs');

// 3. Public Caddy On-Demand TLS Endpoint (Must be before tenant gateway check)
app.use('/api/v1/domains', caddyRoutes);

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
