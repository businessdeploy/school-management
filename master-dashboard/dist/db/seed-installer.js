"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SeedInstaller = void 0;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const fleet_db_1 = require("./fleet-db");
const config_1 = require("../config");
class SeedInstaller {
    /**
     * Provision and seed a dedicated database for a new school.
     */
    static async provisionTenantDatabase(options) {
        const dbName = `${config_1.config.fleetDb.databasePrefix}${options.slug}`;
        console.log(`[Provisioner] Initializing tenant database: ${dbName}`);
        // 1. Ensure tenant filesystem storage exists
        const tenantDir = path_1.default.join(config_1.config.tenantsStoragePath, options.slug);
        const uploadsDir = path_1.default.join(tenantDir, 'uploads');
        const backupDir = path_1.default.join(tenantDir, 'backup');
        if (!fs_1.default.existsSync(uploadsDir))
            fs_1.default.mkdirSync(uploadsDir, { recursive: true });
        if (!fs_1.default.existsSync(backupDir))
            fs_1.default.mkdirSync(backupDir, { recursive: true });
        // 2. Check if Fleet DB is reachable
        const isDbOnline = await fleet_db_1.FleetDb.testConnection();
        if (!isDbOnline) {
            console.warn(`[Provisioner] Fleet MariaDB is not reachable at ${config_1.config.fleetDb.host}:${config_1.config.fleetDb.port}. Registering metadata in master store.`);
            return;
        }
        // 3. Create Database
        await fleet_db_1.FleetDb.createDatabase(dbName);
        // 4. Import database.sql schema
        if (fs_1.default.existsSync(config_1.config.sqlSeedPath)) {
            console.log(`[Provisioner] Importing 196 tables from: ${config_1.config.sqlSeedPath}`);
            let sqlContent = fs_1.default.readFileSync(config_1.config.sqlSeedPath, 'utf-8');
            // Ensure all CREATE TABLE statements are idempotent
            sqlContent = sqlContent.replace(/CREATE TABLE `/gi, 'CREATE TABLE IF NOT EXISTS `');
            const pool = fleet_db_1.FleetDb.getPool();
            const conn = await pool.getConnection();
            try {
                await conn.query(`USE \`${dbName}\`;`);
                await conn.query('SET FOREIGN_KEY_CHECKS = 0;');
                await conn.query(sqlContent);
                await conn.query('SET FOREIGN_KEY_CHECKS = 1;');
                console.log(`[Provisioner] Schema imported successfully into ${dbName}`);
            }
            finally {
                conn.release();
            }
        }
        else {
            console.warn(`[Provisioner] Seed SQL not found at ${config_1.config.sqlSeedPath}. Skipping schema import.`);
        }
        // 5. Update sch_settings
        try {
            const baseUrl = options.domain.includes('localhost')
                ? `http://${options.domain}/`
                : `https://${options.domain}/`;
            const timezone = options.timezone || 'UTC';
            const currency = options.currencySymbol || '$';
            await fleet_db_1.FleetDb.executeQuery(dbName, `UPDATE \`sch_settings\` SET \`name\` = ?, \`email\` = ?, \`base_url\` = ?, \`currency_symbol\` = ?, \`timezone\` = ? WHERE \`id\` = 1`, [options.name, options.adminEmail, baseUrl, currency, timezone]);
        }
        catch (err) {
            console.error(`[Provisioner] Error updating sch_settings in ${dbName}:`, err);
        }
        // 6. Insert / Update Super Admin Staff
        try {
            const adminPass = options.adminPassword || 'Admin@123456';
            // PHP password_hash uses bcrypt ($2y$), Node's bcrypt matches verification
            const salt = bcryptjs_1.default.genSaltSync(10);
            const hashedPassword = bcryptjs_1.default.hashSync(adminPass, salt).replace(/^\$2a\$/, '$2y$');
            // Check if employee 9000 exists
            const existing = await fleet_db_1.FleetDb.executeQuery(dbName, `SELECT id FROM \`staff\` WHERE \`employee_id\` = '9000' OR \`email\` = ? LIMIT 1`, [options.adminEmail]);
            if (Array.isArray(existing) && existing.length > 0) {
                await fleet_db_1.FleetDb.executeQuery(dbName, `UPDATE \`staff\` SET \`email\` = ?, \`password\` = ?, \`is_active\` = 1 WHERE \`id\` = ?`, [options.adminEmail, hashedPassword, existing[0].id]);
            }
            else {
                const staffResult = await fleet_db_1.FleetDb.executeQuery(dbName, `INSERT INTO \`staff\` (\`employee_id\`, \`name\`, \`surname\`, \`dob\`, \`gender\`, \`email\`, \`password\`, \`is_active\`) 
           VALUES ('9000', 'Super', 'Admin', '2000-01-01', 'Male', ?, ?, 1)`, [options.adminEmail, hashedPassword]);
                const newStaffId = staffResult.insertId || 1;
                await fleet_db_1.FleetDb.executeQuery(dbName, `INSERT INTO \`staff_roles\` (\`staff_id\`, \`role_id\`) VALUES (?, 7)`, [newStaffId]);
            }
            console.log(`[Provisioner] Super Admin created for ${options.adminEmail}`);
        }
        catch (err) {
            console.error(`[Provisioner] Error setting up Super Admin in ${dbName}:`, err);
        }
    }
}
exports.SeedInstaller = SeedInstaller;
