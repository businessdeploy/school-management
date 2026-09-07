"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const express_session_1 = __importDefault(require("express-session"));
const path_1 = __importDefault(require("path"));
const config_1 = require("./config");
const master_db_1 = require("./db/master-db");
const docker_service_1 = require("./services/docker-service");
const gateway_proxy_1 = require("./services/gateway-proxy");
const data_aggregator_1 = require("./services/data-aggregator");
const auth_routes_1 = __importStar(require("./routes/auth-routes"));
const school_routes_1 = __importDefault(require("./routes/school-routes"));
const analytics_routes_1 = __importDefault(require("./routes/analytics-routes"));
const network_routes_1 = __importDefault(require("./routes/network-routes"));
const caddy_routes_1 = __importDefault(require("./routes/caddy-routes"));
const fs_1 = __importDefault(require("fs"));
const app = (0, express_1.default)();
// 1. Initialize Subsystems
master_db_1.MasterDb.init();
docker_service_1.DockerService.init();
gateway_proxy_1.GatewayProxy.init();
// 2. View Engine (EJS)
const viewsPath = fs_1.default.existsSync(path_1.default.join(__dirname, 'views'))
    ? path_1.default.join(__dirname, 'views')
    : path_1.default.resolve(__dirname, '../src/views');
app.set('views', viewsPath);
app.set('view engine', 'ejs');
// 3. Static Assets & Body Parsers
app.use(express_1.default.static(path_1.default.join(__dirname, '../public')));
app.use(express_1.default.json());
app.use(express_1.default.urlencoded({ extended: true }));
// 4. Session Middleware
app.use((0, express_session_1.default)({
    secret: config_1.config.sessionSecret,
    resave: false,
    saveUninitialized: false,
    cookie: { secure: false, maxAge: 86400000 }, // 24 hours
}));
// 5. Caddy On-Demand TLS Validation (Must be public before gateway check)
app.use('/api/v1/domains', caddy_routes_1.default);
// 6. Intelligent Tenant Gateway Router
// Inspects host header: if request is for a school instance, routes to container or suspension page
app.use(gateway_proxy_1.GatewayProxy.handleTenantRouting);
// 7. Master Auth Routes
app.use('/auth', auth_routes_1.default);
// 8. Master Dashboard Protected Routes
app.use((req, res, next) => {
    res.locals.user = req.session?.user || null;
    res.locals.currentPath = req.path;
    next();
});
// Overview Dashboard
app.get('/', auth_routes_1.requireAuth, async (req, res) => {
    const telemetry = await data_aggregator_1.DataAggregator.getFleetTelemetry();
    const schools = master_db_1.MasterDb.getSchools();
    const networks = master_db_1.MasterDb.getNetworks();
    const clients = master_db_1.MasterDb.getClients();
    res.render('dashboard', {
        pageTitle: 'Master Fleet Control Plane',
        telemetry,
        schools,
        networks,
        clients,
    });
});
app.use('/schools', auth_routes_1.requireAuth, school_routes_1.default);
app.use('/master-data', auth_routes_1.requireAuth, analytics_routes_1.default);
app.use('/networks', auth_routes_1.requireAuth, network_routes_1.default);
// 404 Fallback
app.use((req, res) => {
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
app.use((err, req, res, next) => {
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
app.listen(config_1.config.port, config_1.config.host, () => {
    console.log(`=======================================================`);
    console.log(`🚀 Smart School Master Control Plane is Online!`);
    console.log(`🌐 Dashboard URL: http://${config_1.config.host}:${config_1.config.port}`);
    console.log(`🔑 Default Login: ${config_1.config.masterAdminUsername} / ${config_1.config.masterAdminPassword}`);
    console.log(`🔒 Cryptographic SSO Secret: Active`);
    console.log(`=======================================================`);
});
