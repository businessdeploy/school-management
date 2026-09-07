"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.FleetDb = void 0;
const promise_1 = __importDefault(require("mysql2/promise"));
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const config_1 = require("../config");
class FleetDb {
    static pool = null;
    static isConnected = false;
    static getPool() {
        if (!this.pool) {
            this.pool = promise_1.default.createPool({
                host: config_1.config.fleetDb.host,
                port: config_1.config.fleetDb.port,
                user: config_1.config.fleetDb.user,
                password: config_1.config.fleetDb.password,
                waitForConnections: true,
                connectionLimit: 10,
                queueLimit: 0,
                multipleStatements: true,
            });
        }
        return this.pool;
    }
    static async testConnection() {
        try {
            const pool = this.getPool();
            const [rows] = await pool.query('SELECT 1 as connected');
            this.isConnected = true;
            return true;
        }
        catch (err) {
            this.isConnected = false;
            return false;
        }
    }
    static async createDatabase(dbName) {
        const pool = this.getPool();
        await pool.query(`CREATE DATABASE IF NOT EXISTS \`${dbName}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
    }
    static async dropDatabase(dbName) {
        const pool = this.getPool();
        await pool.query(`DROP DATABASE IF EXISTS \`${dbName}\`;`);
    }
    static async executeQuery(dbName, sql, params = []) {
        const pool = this.getPool();
        const conn = await pool.getConnection();
        try {
            await conn.query(`USE \`${dbName}\`;`);
            const [results] = await conn.query(sql, params);
            return results;
        }
        finally {
            conn.release();
        }
    }
    /**
     * Fetch live telemetry for a tenant database: table count, storage size, student & staff counts.
     */
    static async getTenantStats(dbName) {
        try {
            const pool = this.getPool();
            const conn = await pool.getConnection();
            try {
                const [tableStats] = await conn.query(`SELECT 
             COUNT(*) as tableCount,
             COALESCE(ROUND(SUM(data_length + index_length) / 1024 / 1024, 2), 0) as sizeMb
           FROM information_schema.tables 
           WHERE table_schema = ?`, [dbName]);
                const tableCount = Number(tableStats[0]?.tableCount || 0);
                const sizeMb = Number(tableStats[0]?.sizeMb || 0);
                if (tableCount === 0) {
                    return { tableCount: 0, sizeMb: 0, studentsCount: 0, staffCount: 0, isOnline: false };
                }
                let staffCount = 0;
                try {
                    const [staffRes] = await conn.query(`SELECT COUNT(*) as cnt FROM \`${dbName}\`.\`staff\``);
                    staffCount = Number(staffRes[0]?.cnt || 0);
                }
                catch (e) { }
                let studentsCount = 0;
                try {
                    const [studentRes] = await conn.query(`SELECT COUNT(*) as cnt FROM \`${dbName}\`.\`students\``);
                    studentsCount = Number(studentRes[0]?.cnt || 0);
                }
                catch (e) { }
                return {
                    tableCount,
                    sizeMb,
                    studentsCount,
                    staffCount,
                    isOnline: true,
                };
            }
            finally {
                conn.release();
            }
        }
        catch (err) {
            console.error(`[FleetDb] Error fetching stats for ${dbName}:`, err);
            return { tableCount: 0, sizeMb: 0, studentsCount: 0, staffCount: 0, isOnline: false };
        }
    }
    /**
     * Reset the Super Admin staff password in a tenant database.
     */
    static async resetAdminPassword(dbName, adminEmail, plainPassword) {
        const salt = bcryptjs_1.default.genSaltSync(10);
        const hashedPassword = bcryptjs_1.default.hashSync(plainPassword, salt).replace(/^\$2a\$/, '$2y$');
        const pool = this.getPool();
        const conn = await pool.getConnection();
        try {
            await conn.query(`UPDATE \`${dbName}\`.\`staff\` 
         SET \`password\` = ? 
         WHERE \`id\` = 1 OR \`employee_id\` = '9000' OR \`email\` = ?`, [hashedPassword, adminEmail]);
            console.log(`[FleetDb] Reset Super Admin password for ${adminEmail} in ${dbName}`);
        }
        finally {
            conn.release();
        }
    }
    /**
     * Update school identity settings in the tenant's sch_settings table.
     */
    static async updateSchoolSettings(dbName, name, email) {
        const pool = this.getPool();
        const conn = await pool.getConnection();
        try {
            await conn.query(`UPDATE \`${dbName}\`.\`sch_settings\` SET \`name\` = ?, \`email\` = ? WHERE \`id\` = 1`, [name, email]);
        }
        catch (e) {
            console.warn(`[FleetDb] Notice: Failed to update sch_settings in ${dbName}:`, e);
        }
        finally {
            conn.release();
        }
    }
    /**
     * Generates a complete SQL dump of a tenant database.
     */
    static async generateSqlDump(dbName, schoolName, slug) {
        const pool = this.getPool();
        const conn = await pool.getConnection();
        try {
            const [tables] = await conn.query(`SELECT TABLE_NAME as tableName FROM information_schema.tables WHERE TABLE_SCHEMA = ? ORDER BY TABLE_NAME ASC`, [dbName]);
            let sqlDump = `-- ========================================================\n`;
            sqlDump += `-- Smart School Master Fleet Database Backup\n`;
            sqlDump += `-- School: ${schoolName} (Slug: ${slug})\n`;
            sqlDump += `-- Database: ${dbName}\n`;
            sqlDump += `-- Generated: ${new Date().toISOString()}\n`;
            sqlDump += `-- ========================================================\n\n`;
            sqlDump += `SET NAMES utf8mb4;\n`;
            sqlDump += `SET FOREIGN_KEY_CHECKS = 0;\n`;
            sqlDump += `SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";\n\n`;
            for (const t of tables) {
                const tableName = t.tableName || t.TABLE_NAME || t.table_name || Object.values(t)[0];
                if (!tableName)
                    continue;
                const [createRes] = await conn.query(`SHOW CREATE TABLE \`${dbName}\`.\`${tableName}\``);
                const createSql = createRes[0]['Create Table'] || createRes[0]['create table'];
                sqlDump += `-- Table structure for table \`${tableName}\`\n`;
                sqlDump += `DROP TABLE IF EXISTS \`${tableName}\`;\n`;
                sqlDump += `${createSql};\n\n`;
                // Table data
                const [rows] = await conn.query(`SELECT * FROM \`${dbName}\`.\`${tableName}\``);
                if (Array.isArray(rows) && rows.length > 0) {
                    sqlDump += `-- Dumping data for table \`${tableName}\` (${rows.length} rows)\n`;
                    const cols = Object.keys(rows[0]).map((c) => `\`${c}\``).join(', ');
                    const chunkSize = 50;
                    for (let i = 0; i < rows.length; i += chunkSize) {
                        const chunk = rows.slice(i, i + chunkSize);
                        const valuesList = chunk
                            .map((row) => {
                            const vals = Object.values(row).map((val) => {
                                if (val === null || val === undefined)
                                    return 'NULL';
                                if (typeof val === 'number')
                                    return String(val);
                                if (typeof val === 'boolean')
                                    return val ? '1' : '0';
                                if (Buffer.isBuffer(val))
                                    return `0x${val.toString('hex')}`;
                                if (val instanceof Date) {
                                    if (isNaN(val.getTime()))
                                        return "'0000-00-00 00:00:00'";
                                    return `'${val.toISOString().slice(0, 19).replace('T', ' ')}'`;
                                }
                                const strVal = String(val)
                                    .replace(/\\/g, '\\\\')
                                    .replace(/'/g, "\\'")
                                    .replace(/\n/g, '\\n')
                                    .replace(/\r/g, '\\r');
                                return `'${strVal}'`;
                            });
                            return `(${vals.join(', ')})`;
                        })
                            .join(',\n');
                        sqlDump += `INSERT INTO \`${tableName}\` (${cols}) VALUES\n${valuesList};\n`;
                    }
                    sqlDump += `\n`;
                }
            }
            sqlDump += `SET FOREIGN_KEY_CHECKS = 1;\n`;
            sqlDump += `-- Dump completed on ${new Date().toISOString()}\n`;
            return sqlDump;
        }
        finally {
            conn.release();
        }
    }
}
exports.FleetDb = FleetDb;
