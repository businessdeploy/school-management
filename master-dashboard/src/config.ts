import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  host: process.env.HOST || '0.0.0.0',
  env: process.env.NODE_ENV || 'development',
  demoMode: process.env.DEMO_MODE === 'true',

  // Master Dashboard Authentication
  masterAdminUsername: process.env.MASTER_ADMIN_USER || '',
  masterAdminPassword: process.env.MASTER_ADMIN_PASS || '',
  sessionSecret: process.env.SESSION_SECRET || process.env.MASTER_SSO_SECRET || '',

  // SSO Impersonator Secret (Must match Smart School PHP MASTER_SSO_SECRET)
  masterSsoSecret: process.env.MASTER_SSO_SECRET || '',

  // Master Domain & Networks
  masterDomain: process.env.MASTER_DOMAIN || 'manage-school-crm.4d68er.easypanel.host',
  defaultNetworkDomain: process.env.DEFAULT_NETWORK_DOMAIN || 'manage-school-crm.4d68er.easypanel.host',

  // Fleet MariaDB Configuration
  fleetDb: {
    host: process.env.FLEET_DB_HOST || '127.0.0.1',
    port: parseInt(process.env.FLEET_DB_PORT || '3306', 10),
    user: process.env.FLEET_DB_USER || 'root',
    password: process.env.FLEET_DB_PASSWORD || '',
    masterDatabase: process.env.MASTER_DB_NAME || 'ss_master_orchestrator',
    databasePrefix: process.env.DB_PREFIX || 'ss_tenant_',
  },

  // Smart School Codebase Path
  appRoot: path.resolve(__dirname, '../../..'),
  sqlSeedPath: process.env.SQL_SEED_PATH ||
    (fs.existsSync(path.resolve(__dirname, 'database.sql'))
      ? path.resolve(__dirname, 'database.sql')
      : (fs.existsSync(path.resolve(__dirname, '../src/database.sql'))
        ? path.resolve(__dirname, '../src/database.sql')
        : path.resolve(__dirname, '../../../application/controllers/install/database.sql'))),
  tenantsStoragePath: process.env.TENANTS_STORAGE_PATH || path.resolve(__dirname, '../../../tenants'),

  // Base Docker Image Name for School Tenants
  tenantDockerImage: process.env.TENANT_DOCKER_IMAGE || 'smartschool-base:latest',
  dockerNetwork: process.env.DOCKER_NETWORK || 'smartschool_network',

  // SMTP Email Configuration for Magic Links & Notifications
  smtp: {
    host: process.env.SMTP_HOST || '',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true' || process.env.SMTP_PORT === '465',
    user: process.env.SMTP_USER || '',
    pass: process.env.SMTP_PASS || '',
    from: process.env.SMTP_FROM || 'Prime School Fleet Control <no-reply@businessdeploy.com>',
  },
};

/**
 * Fails fast when security-critical secrets are missing, so the control plane
 * never starts with empty or well-known credentials.
 */
export function validateConfig(): void {
  const missing: string[] = [];
  if (!config.masterAdminUsername) missing.push('MASTER_ADMIN_USER');
  if (!config.masterAdminPassword) missing.push('MASTER_ADMIN_PASS');
  if (!config.sessionSecret) missing.push('SESSION_SECRET');
  if (!config.masterSsoSecret) missing.push('MASTER_SSO_SECRET');
  if (!config.fleetDb.password) missing.push('FLEET_DB_PASSWORD');

  if (missing.length > 0) {
    throw new Error(
      `Master Dashboard is missing required secrets: ${missing.join(', ')}. ` +
        'Configure them via environment variables or a .env file (see .env.example).'
    );
  }
}
