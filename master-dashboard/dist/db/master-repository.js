"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MasterRepository = void 0;
exports.ensureMasterSchema = ensureMasterSchema;
const config_1 = require("../config");
const fleet_db_1 = require("./fleet-db");
const MASTER_SCHEMA_STATEMENTS = [
    `CREATE TABLE IF NOT EXISTS master_migrations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    version INT NOT NULL UNIQUE,
    name VARCHAR(191) NOT NULL,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    `CREATE TABLE IF NOT EXISTS networks (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(191) NOT NULL,
    root_domain VARCHAR(191) NOT NULL,
    is_default TINYINT(1) NOT NULL DEFAULT 0,
    description VARCHAR(500) NULL,
    created_at VARCHAR(64) NOT NULL,
    UNIQUE KEY uq_networks_root_domain (root_domain)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    `CREATE TABLE IF NOT EXISTS clients (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(191) NOT NULL,
    organization VARCHAR(191) NULL,
    email VARCHAR(191) NULL,
    phone VARCHAR(64) NULL,
    plan VARCHAR(32) NOT NULL DEFAULT 'Starter',
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    created_at VARCHAR(64) NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    `CREATE TABLE IF NOT EXISTS schools (
    id VARCHAR(64) PRIMARY KEY,
    slug VARCHAR(64) NOT NULL,
    name VARCHAR(191) NOT NULL,
    client_id VARCHAR(64) NULL,
    network_id VARCHAR(64) NULL,
    subdomain VARCHAR(191) NOT NULL,
    custom_domain VARCHAR(191) NULL,
    db_name VARCHAR(191) NOT NULL,
    container_name VARCHAR(191) NOT NULL,
    admin_email VARCHAR(191) NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'provisioning',
    storage_quota_gb INT NOT NULL DEFAULT 10,
    max_students INT NOT NULL DEFAULT 1000,
    ssl_status VARCHAR(32) NOT NULL DEFAULT 'n/a',
    created_at VARCHAR(64) NOT NULL,
    updated_at VARCHAR(64) NOT NULL,
    UNIQUE KEY uq_schools_slug (slug),
    UNIQUE KEY uq_schools_custom_domain (custom_domain),
    CONSTRAINT fk_schools_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
    CONSTRAINT fk_schools_network FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE SET NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    `CREATE TABLE IF NOT EXISTS admin_users (
    id VARCHAR(64) PRIMARY KEY,
    username VARCHAR(191) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(191) NULL,
    role VARCHAR(32) NOT NULL DEFAULT 'superadmin',
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    mfa_secret VARCHAR(255) NULL,
    created_at VARCHAR(64) NOT NULL,
    updated_at VARCHAR(64) NOT NULL,
    UNIQUE KEY uq_admin_users_username (username)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    `CREATE TABLE IF NOT EXISTS sessions (
    sid VARCHAR(255) PRIMARY KEY,
    session_data TEXT NOT NULL,
    expires_at BIGINT NOT NULL
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    `CREATE TABLE IF NOT EXISTS operations (
    id VARCHAR(64) PRIMARY KEY,
    type VARCHAR(64) NOT NULL,
    school_id VARCHAR(64) NULL,
    idempotency_key VARCHAR(191) NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    operator VARCHAR(191) NULL,
    created_at VARCHAR(64) NOT NULL,
    updated_at VARCHAR(64) NOT NULL,
    UNIQUE KEY uq_operations_idempotency_key (idempotency_key)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    `CREATE TABLE IF NOT EXISTS operation_steps (
    id INT AUTO_INCREMENT PRIMARY KEY,
    operation_id VARCHAR(64) NOT NULL,
    step VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    message TEXT NULL,
    created_at VARCHAR(64) NOT NULL,
    updated_at VARCHAR(64) NOT NULL,
    KEY idx_operation_steps_operation_id (operation_id),
    CONSTRAINT fk_operation_steps_operation FOREIGN KEY (operation_id) REFERENCES operations(id) ON DELETE CASCADE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
];
function mapNetworkRow(row) {
    return {
        id: row.id,
        name: row.name,
        rootDomain: row.root_domain,
        isDefault: !!row.is_default,
        description: row.description || undefined,
        createdAt: row.created_at,
    };
}
function mapClientRow(row) {
    return {
        id: row.id,
        name: row.name,
        organization: row.organization || '',
        email: row.email || '',
        phone: row.phone || '',
        plan: row.plan,
        status: row.status,
        createdAt: row.created_at,
    };
}
function mapSchoolRow(row) {
    return {
        id: row.id,
        slug: row.slug,
        name: row.name,
        clientId: row.client_id,
        networkId: row.network_id,
        subdomain: row.subdomain,
        customDomain: row.custom_domain || undefined,
        dbName: row.db_name,
        containerName: row.container_name,
        adminEmail: row.admin_email,
        status: row.status,
        storageQuotaGb: Number(row.storage_quota_gb),
        maxStudents: Number(row.max_students),
        sslStatus: row.ssl_status,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
    };
}
function mapAdminUserRow(row) {
    return {
        id: row.id,
        username: row.username,
        passwordHash: row.password_hash,
        displayName: row.display_name || undefined,
        role: row.role,
        isActive: !!row.is_active,
        mfaSecret: row.mfa_secret || undefined,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
    };
}
function mapOperationRow(row) {
    return {
        id: row.id,
        type: row.type,
        schoolId: row.school_id || undefined,
        idempotencyKey: row.idempotency_key || undefined,
        status: row.status,
        operator: row.operator || undefined,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
    };
}
function mapOperationStepRow(row) {
    return {
        id: row.id,
        operationId: row.operation_id,
        step: row.step,
        status: row.status,
        message: row.message || undefined,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
    };
}
async function masterQuery(sql, params = []) {
    return fleet_db_1.FleetDb.executeQuery(config_1.config.fleetDb.masterDatabase, sql, params);
}
/**
 * Creates the master database and transactional tables if they do not exist.
 * Idempotent and safe to run on every startup.
 */
async function ensureMasterSchema() {
    const pool = fleet_db_1.FleetDb.getPool();
    const conn = await pool.getConnection();
    try {
        await conn.query(`CREATE DATABASE IF NOT EXISTS \`${config_1.config.fleetDb.masterDatabase}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
        await conn.query(`USE \`${config_1.config.fleetDb.masterDatabase}\``);
        for (const stmt of MASTER_SCHEMA_STATEMENTS) {
            await conn.query(stmt);
        }
    }
    finally {
        conn.release();
    }
}
class MasterRepository {
    // ---- Networks ----
    static async listNetworks() {
        const rows = await masterQuery('SELECT * FROM networks ORDER BY is_default DESC, created_at ASC');
        return rows.map(mapNetworkRow);
    }
    static async getNetworkById(id) {
        const rows = await masterQuery('SELECT * FROM networks WHERE id = ? LIMIT 1', [id]);
        return rows[0] ? mapNetworkRow(rows[0]) : undefined;
    }
    static async createNetwork(network) {
        await masterQuery(`INSERT INTO networks (id, name, root_domain, is_default, description, created_at) VALUES (?, ?, ?, ?, ?, ?)`, [
            network.id,
            network.name,
            network.rootDomain,
            network.isDefault ? 1 : 0,
            network.description || null,
            network.createdAt,
        ]);
    }
    // ---- Clients ----
    static async listClients() {
        const rows = await masterQuery('SELECT * FROM clients ORDER BY created_at ASC');
        return rows.map(mapClientRow);
    }
    static async getClientById(id) {
        const rows = await masterQuery('SELECT * FROM clients WHERE id = ? LIMIT 1', [id]);
        return rows[0] ? mapClientRow(rows[0]) : undefined;
    }
    static async createClient(client) {
        await masterQuery(`INSERT INTO clients (id, name, organization, email, phone, plan, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, [
            client.id,
            client.name,
            client.organization || null,
            client.email || null,
            client.phone || null,
            client.plan,
            client.status,
            client.createdAt,
        ]);
    }
    // ---- Schools ----
    static async listSchools() {
        const rows = await masterQuery('SELECT * FROM schools ORDER BY created_at ASC');
        return rows.map(mapSchoolRow);
    }
    static async getSchoolById(id) {
        const rows = await masterQuery('SELECT * FROM schools WHERE id = ? LIMIT 1', [id]);
        return rows[0] ? mapSchoolRow(rows[0]) : undefined;
    }
    static async getSchoolBySlug(slug) {
        const rows = await masterQuery('SELECT * FROM schools WHERE LOWER(slug) = ? LIMIT 1', [slug.toLowerCase()]);
        return rows[0] ? mapSchoolRow(rows[0]) : undefined;
    }
    static async getSchoolByDomain(domain) {
        const cleanDomain = domain.split(':')[0].toLowerCase();
        const rows = await masterQuery('SELECT * FROM schools WHERE LOWER(subdomain) = ? OR LOWER(custom_domain) = ? LIMIT 1', [cleanDomain, cleanDomain]);
        return rows[0] ? mapSchoolRow(rows[0]) : undefined;
    }
    static async createSchool(school) {
        await masterQuery(`INSERT INTO schools
        (id, slug, name, client_id, network_id, subdomain, custom_domain, db_name, container_name,
         admin_email, status, storage_quota_gb, max_students, ssl_status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, [
            school.id,
            school.slug,
            school.name,
            school.clientId || null,
            school.networkId || null,
            school.subdomain,
            school.customDomain || null,
            school.dbName,
            school.containerName,
            school.adminEmail || null,
            school.status,
            school.storageQuotaGb,
            school.maxStudents,
            school.sslStatus,
            school.createdAt,
            school.updatedAt,
        ]);
    }
    static async updateSchool(id, updates) {
        const fields = {
            name: updates.name,
            admin_email: updates.adminEmail,
            custom_domain: updates.customDomain || null,
            subdomain: updates.subdomain,
            db_name: updates.dbName,
            container_name: updates.containerName,
            status: updates.status,
            storage_quota_gb: updates.storageQuotaGb,
            max_students: updates.maxStudents,
            ssl_status: updates.sslStatus,
            client_id: updates.clientId,
            network_id: updates.networkId,
        };
        const columns = Object.entries(fields).filter(([, v]) => v !== undefined);
        if (columns.length === 0)
            return true;
        const setClause = columns.map(([col]) => `\`${col}\` = ?`).join(', ');
        const params = columns.map(([, v]) => v);
        params.push(new Date().toISOString());
        params.push(id);
        const result = await masterQuery(`UPDATE schools SET ${setClause}, updated_at = ? WHERE id = ?`, params);
        return result?.affectedRows === 1;
    }
    static async deleteSchool(id) {
        const result = await masterQuery('DELETE FROM schools WHERE id = ?', [id]);
        return result?.affectedRows === 1;
    }
    // ---- Admin Users ----
    static async listAdminUsers() {
        const rows = await masterQuery('SELECT * FROM admin_users ORDER BY created_at ASC');
        return rows.map(mapAdminUserRow);
    }
    static async getAdminUserByUsername(username) {
        const rows = await masterQuery('SELECT * FROM admin_users WHERE username = ? LIMIT 1', [username]);
        return rows[0] ? mapAdminUserRow(rows[0]) : undefined;
    }
    static async getAdminUserById(id) {
        const rows = await masterQuery('SELECT * FROM admin_users WHERE id = ? LIMIT 1', [id]);
        return rows[0] ? mapAdminUserRow(rows[0]) : undefined;
    }
    static async updateAdminUser(id, updates) {
        const fields = {
            username: updates.username,
            password_hash: updates.passwordHash,
            display_name: updates.displayName || null,
            role: updates.role,
            is_active: updates.isActive === undefined ? undefined : updates.isActive ? 1 : 0,
            mfa_secret: updates.mfaSecret === undefined ? undefined : updates.mfaSecret || null,
        };
        const columns = Object.entries(fields).filter(([, v]) => v !== undefined);
        if (columns.length === 0)
            return true;
        const setClause = columns.map(([col]) => `\`${col}\` = ?`).join(', ');
        const params = columns.map(([, v]) => v);
        params.push(new Date().toISOString());
        params.push(id);
        const result = await masterQuery(`UPDATE admin_users SET ${setClause}, updated_at = ? WHERE id = ?`, params);
        return result?.affectedRows === 1;
    }
    static async setAdminUserMfaSecret(id, secret) {
        const result = await masterQuery('UPDATE admin_users SET mfa_secret = ?, updated_at = ? WHERE id = ?', [
            secret,
            new Date().toISOString(),
            id,
        ]);
        return result?.affectedRows === 1;
    }
    // ---- Operations ----
    static async createOperation(op) {
        await masterQuery(`INSERT INTO operations (id, type, school_id, idempotency_key, status, operator, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, [op.id, op.type, op.schoolId || null, op.idempotencyKey || null, op.status, op.operator || null, op.createdAt, op.updatedAt]);
    }
    static async getOperationById(id) {
        const rows = await masterQuery('SELECT * FROM operations WHERE id = ? LIMIT 1', [id]);
        return rows[0] ? mapOperationRow(rows[0]) : undefined;
    }
    static async getOperationByKey(idempotencyKey) {
        const rows = await masterQuery('SELECT * FROM operations WHERE idempotency_key = ? LIMIT 1', [idempotencyKey]);
        return rows[0] ? mapOperationRow(rows[0]) : undefined;
    }
    static async listOperations() {
        const rows = await masterQuery('SELECT * FROM operations ORDER BY created_at DESC');
        return rows.map(mapOperationRow);
    }
    static async updateOperationStatus(id, status) {
        await masterQuery('UPDATE operations SET status = ?, updated_at = ? WHERE id = ?', [
            status,
            new Date().toISOString(),
            id,
        ]);
    }
    static async markStaleRunningOperationsFailed(beforeIso) {
        const result = await masterQuery('UPDATE operations SET status = ?, updated_at = ? WHERE status = ? AND updated_at < ?', ['failed', new Date().toISOString(), 'running', beforeIso]);
        return result?.affectedRows || 0;
    }
    static async addOperationStep(step) {
        const result = await masterQuery(`INSERT INTO operation_steps (operation_id, step, status, message, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?)`, [step.operationId, step.step, step.status, step.message || null, step.createdAt, step.updatedAt]);
        return result?.insertId || 0;
    }
    static async updateOperationStep(id, status, message) {
        await masterQuery('UPDATE operation_steps SET status = ?, message = ?, updated_at = ? WHERE id = ?', [
            status,
            message || null,
            new Date().toISOString(),
            id,
        ]);
    }
    static async createAdminUser(user) {
        await masterQuery(`INSERT INTO admin_users (id, username, password_hash, display_name, role, is_active, mfa_secret, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`, [
            user.id,
            user.username,
            user.passwordHash,
            user.displayName || null,
            user.role,
            user.isActive ? 1 : 0,
            user.mfaSecret || null,
            user.createdAt,
            user.updatedAt,
        ]);
    }
    /**
     * Imports a full master store (networks, clients, schools) in a single
     * transaction so a partial failure rolls back cleanly.
     */
    static async importAll(networks, clients, schools) {
        const pool = fleet_db_1.FleetDb.getPool();
        const conn = await pool.getConnection();
        try {
            await conn.query(`USE \`${config_1.config.fleetDb.masterDatabase}\``);
            await conn.beginTransaction();
            try {
                for (const n of networks) {
                    await conn.query(`INSERT INTO networks (id, name, root_domain, is_default, description, created_at) VALUES (?, ?, ?, ?, ?, ?)`, [n.id, n.name, n.rootDomain, n.isDefault ? 1 : 0, n.description || null, n.createdAt]);
                }
                for (const c of clients) {
                    await conn.query(`INSERT INTO clients (id, name, organization, email, phone, plan, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, [c.id, c.name, c.organization || null, c.email || null, c.phone || null, c.plan, c.status, c.createdAt]);
                }
                for (const s of schools) {
                    await conn.query(`INSERT INTO schools
              (id, slug, name, client_id, network_id, subdomain, custom_domain, db_name, container_name,
               admin_email, status, storage_quota_gb, max_students, ssl_status, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, [
                        s.id,
                        s.slug,
                        s.name,
                        s.clientId || null,
                        s.networkId || null,
                        s.subdomain,
                        s.customDomain || null,
                        s.dbName,
                        s.containerName,
                        s.adminEmail || null,
                        s.status,
                        s.storageQuotaGb,
                        s.maxStudents,
                        s.sslStatus,
                        s.createdAt,
                        s.updatedAt,
                    ]);
                }
                await conn.commit();
            }
            catch (err) {
                await conn.rollback();
                throw err;
            }
            return { networks: networks.length, clients: clients.length, schools: schools.length };
        }
        finally {
            conn.release();
        }
    }
}
exports.MasterRepository = MasterRepository;
