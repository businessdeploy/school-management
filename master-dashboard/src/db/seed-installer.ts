import fs from 'fs';
import path from 'path';
import bcrypt from 'bcryptjs';
import { FleetDb } from './fleet-db';
import { config } from '../config';

export interface SchoolSeedOptions {
  slug: string;
  name: string;
  domain: string;
  adminEmail: string;
  adminPassword?: string;
  currencySymbol?: string;
  timezone?: string;
}

export class SeedInstaller {
  /**
   * Provision and seed a dedicated database for a new school.
   */
  public static async provisionTenantDatabase(options: SchoolSeedOptions): Promise<void> {
    const dbName = `${config.fleetDb.databasePrefix}${options.slug}`;
    console.log(`[Provisioner] Initializing tenant database: ${dbName}`);

    // 1. Ensure tenant filesystem storage exists
    const tenantDir = path.join(config.tenantsStoragePath, options.slug);
    const uploadsDir = path.join(tenantDir, 'uploads');
    const backupDir = path.join(tenantDir, 'backup');
    if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });
    if (!fs.existsSync(backupDir)) fs.mkdirSync(backupDir, { recursive: true });

    // 2. Check if Fleet DB is reachable
    const isDbOnline = await FleetDb.testConnection();
    if (!isDbOnline) {
      console.warn(`[Provisioner] Fleet MariaDB is not reachable at ${config.fleetDb.host}:${config.fleetDb.port}. Registering metadata in master store.`);
      return;
    }

    // 3. Create Database
    await FleetDb.createDatabase(dbName);

    // 4. Import database.sql schema
    if (fs.existsSync(config.sqlSeedPath)) {
      console.log(`[Provisioner] Importing 196 tables from: ${config.sqlSeedPath}`);
      const sqlContent = fs.readFileSync(config.sqlSeedPath, 'utf-8');
      const pool = FleetDb.getPool();
      const conn = await pool.getConnection();

      try {
        await conn.query(`USE \`${dbName}\`;`);
        await conn.query('SET FOREIGN_KEY_CHECKS = 0;');
        await conn.query(sqlContent);
        await conn.query('SET FOREIGN_KEY_CHECKS = 1;');
        console.log(`[Provisioner] Schema imported successfully into ${dbName}`);
      } finally {
        conn.release();
      }
    } else {
      console.warn(`[Provisioner] Seed SQL not found at ${config.sqlSeedPath}. Skipping schema import.`);
    }

    // 5. Update sch_settings
    try {
      const baseUrl = options.domain.includes('localhost')
        ? `http://${options.domain}/`
        : `https://${options.domain}/`;
      const timezone = options.timezone || 'UTC';
      const currency = options.currencySymbol || '$';

      await FleetDb.executeQuery(
        dbName,
        `UPDATE \`sch_settings\` SET \`name\` = ?, \`email\` = ?, \`base_url\` = ?, \`currency_symbol\` = ?, \`timezone\` = ? WHERE \`id\` = 1`,
        [options.name, options.adminEmail, baseUrl, currency, timezone]
      );
    } catch (err) {
      console.error(`[Provisioner] Error updating sch_settings in ${dbName}:`, err);
    }

    // 6. Insert / Update Super Admin Staff
    try {
      const adminPass = options.adminPassword || 'Admin@123456';
      // PHP password_hash uses bcrypt ($2y$), Node's bcrypt matches verification
      const salt = bcrypt.genSaltSync(10);
      const hashedPassword = bcrypt.hashSync(adminPass, salt).replace(/^\$2a\$/, '$2y$');

      // Check if employee 9000 exists
      const existing = await FleetDb.executeQuery(
        dbName,
        `SELECT id FROM \`staff\` WHERE \`employee_id\` = '9000' OR \`email\` = ? LIMIT 1`,
        [options.adminEmail]
      );

      if (Array.isArray(existing) && existing.length > 0) {
        await FleetDb.executeQuery(
          dbName,
          `UPDATE \`staff\` SET \`email\` = ?, \`password\` = ?, \`is_active\` = 1 WHERE \`id\` = ?`,
          [options.adminEmail, hashedPassword, existing[0].id]
        );
      } else {
        const staffResult: any = await FleetDb.executeQuery(
          dbName,
          `INSERT INTO \`staff\` (\`employee_id\`, \`name\`, \`surname\`, \`dob\`, \`gender\`, \`email\`, \`password\`, \`is_active\`) 
           VALUES ('9000', 'Super', 'Admin', '2000-01-01', 'Male', ?, ?, 1)`,
          [options.adminEmail, hashedPassword]
        );
        const newStaffId = staffResult.insertId || 1;
        await FleetDb.executeQuery(
          dbName,
          `INSERT INTO \`staff_roles\` (\`staff_id\`, \`role_id\`) VALUES (?, 7)`,
          [newStaffId]
        );
      }
      console.log(`[Provisioner] Super Admin created for ${options.adminEmail}`);
    } catch (err) {
      console.error(`[Provisioner] Error setting up Super Admin in ${dbName}:`, err);
    }
  }
}
