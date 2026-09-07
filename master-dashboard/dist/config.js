"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
exports.config = {
    port: parseInt(process.env.PORT || '3000', 10),
    host: process.env.HOST || '0.0.0.0',
    env: process.env.NODE_ENV || 'development',
    // Master Dashboard Authentication
    masterAdminUsername: process.env.MASTER_ADMIN_USER || 'superadmin',
    masterAdminPassword: process.env.MASTER_ADMIN_PASS || 'MasterAdmin2026!',
    sessionSecret: process.env.SESSION_SECRET || 'smartschool-master-super-secret-key-2026',
    // SSO Impersonator Secret (Must match Smart School PHP MASTER_SSO_SECRET)
    masterSsoSecret: process.env.MASTER_SSO_SECRET || 'ss-master-orchestrator-secret-key-2026',
    // Master Domain & Networks
    masterDomain: process.env.MASTER_DOMAIN || 'manage-school-crm.4d68er.easypanel.host',
    defaultNetworkDomain: process.env.DEFAULT_NETWORK_DOMAIN || 'manage-school-crm.4d68er.easypanel.host',
    // Fleet MariaDB Configuration
    fleetDb: {
        host: process.env.FLEET_DB_HOST || '127.0.0.1',
        port: parseInt(process.env.FLEET_DB_PORT || '3306', 10),
        user: process.env.FLEET_DB_USER || 'root',
        password: process.env.FLEET_DB_PASSWORD || 'smartschool_root_pass',
        masterDatabase: process.env.MASTER_DB_NAME || 'ss_master_orchestrator',
        databasePrefix: process.env.DB_PREFIX || 'ss_tenant_',
    },
    // Smart School Codebase Path
    appRoot: path_1.default.resolve(__dirname, '../../..'),
    sqlSeedPath: process.env.SQL_SEED_PATH ||
        (fs_1.default.existsSync(path_1.default.resolve(__dirname, 'database.sql'))
            ? path_1.default.resolve(__dirname, 'database.sql')
            : (fs_1.default.existsSync(path_1.default.resolve(__dirname, '../src/database.sql'))
                ? path_1.default.resolve(__dirname, '../src/database.sql')
                : path_1.default.resolve(__dirname, '../../../application/controllers/install/database.sql'))),
    tenantsStoragePath: process.env.TENANTS_STORAGE_PATH || path_1.default.resolve(__dirname, '../../../tenants'),
    // Base Docker Image Name for School Tenants
    tenantDockerImage: process.env.TENANT_DOCKER_IMAGE || 'smartschool-base:latest',
    dockerNetwork: process.env.DOCKER_NETWORK || 'smartschool_network',
};
