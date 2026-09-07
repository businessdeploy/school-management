import express, { Request, Response } from 'express';
import session from 'express-session';
import path from 'path';
import { config } from './config';
import { MasterDb } from './db/master-db';
import { DockerService } from './services/docker-service';
import { GatewayProxy } from './services/gateway-proxy';
import { DataAggregator } from './services/data-aggregator';

import authRoutes, { requireAuth } from './routes/auth-routes';
import schoolRoutes from './routes/school-routes';
import analyticsRoutes from './routes/analytics-routes';
import networkRoutes from './routes/network-routes';
import caddyRoutes from './routes/caddy-routes';

import fs from 'fs';

const app = express();

// 1. Initialize Subsystems
MasterDb.init();
DockerService.init();
GatewayProxy.init();

// 2. View Engine (EJS)
const viewsPath = fs.existsSync(path.join(__dirname, 'views'))
  ? path.join(__dirname, 'views')
  : path.resolve(__dirname, '../src/views');
app.set('views', viewsPath);
app.set('view engine', 'ejs');

// 3. Static Assets & Body Parsers
app.use(express.static(path.join(__dirname, '../public')));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 4. Session Middleware
app.use(
  session({
    secret: config.sessionSecret,
    resave: false,
    saveUninitialized: false,
    cookie: { secure: false, maxAge: 86400000 }, // 24 hours
  })
);

// 5. Caddy On-Demand TLS Validation (Must be public before gateway check)
app.use('/api/v1/domains', caddyRoutes);

// 6. Intelligent Tenant Gateway Router
// Inspects host header: if request is for a school instance, routes to container or suspension page
app.use(GatewayProxy.handleTenantRouting);

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
  const schools = MasterDb.getSchools();
  const networks = MasterDb.getNetworks();
  const clients = MasterDb.getClients();

  res.render('dashboard', {
    pageTitle: 'Master Fleet Control Plane',
    telemetry,
    schools,
    networks,
    clients,
  });
});

app.use('/schools', requireAuth, schoolRoutes);
app.use('/master-data', requireAuth, analyticsRoutes);
app.use('/networks', requireAuth, networkRoutes);

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
  console.error('[MASTER CONTROL PLANE ERROR]:', err);
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
          <p class="text-sm text-slate-300 mb-3 font-mono bg-slate-950 p-3 rounded-lg border border-slate-800">${err.message || err}</p>
          <pre class="bg-slate-950 p-4 rounded-xl text-xs font-mono text-slate-400 overflow-x-auto border border-slate-800 max-h-64">${err.stack || 'No stack trace available'}</pre>
          <div class="mt-6">
            <a href="/schools" class="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 rounded-xl text-xs font-semibold text-white transition">← Return to Schools</a>
          </div>
        </div>
      </body>
    </html>
  `);
});

// Start Server
app.listen(config.port, config.host, () => {
  console.log(`=======================================================`);
  console.log(`🚀 Smart School Master Control Plane is Online!`);
  console.log(`🌐 Dashboard URL: http://${config.host}:${config.port}`);
  console.log(`🔑 Default Login: ${config.masterAdminUsername} / ${config.masterAdminPassword}`);
  console.log(`🔒 Cryptographic SSO Secret: Active`);
  console.log(`=======================================================`);
});
