import mysql from 'mysql2/promise';
import { config } from '../config';

export class FleetDb {
  private static pool: mysql.Pool | null = null;
  private static isConnected = false;

  public static getPool(): mysql.Pool {
    if (!this.pool) {
      this.pool = mysql.createPool({
        host: config.fleetDb.host,
        port: config.fleetDb.port,
        user: config.fleetDb.user,
        password: config.fleetDb.password,
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0,
        multipleStatements: true,
      });
    }
    return this.pool;
  }

  public static async testConnection(): Promise<boolean> {
    try {
      const pool = this.getPool();
      const [rows] = await pool.query('SELECT 1 as connected');
      this.isConnected = true;
      return true;
    } catch (err) {
      this.isConnected = false;
      return false;
    }
  }

  public static async createDatabase(dbName: string): Promise<void> {
    const pool = this.getPool();
    await pool.query(`CREATE DATABASE IF NOT EXISTS \`${dbName}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
  }

  public static async dropDatabase(dbName: string): Promise<void> {
    const pool = this.getPool();
    await pool.query(`DROP DATABASE IF EXISTS \`${dbName}\`;`);
  }

  public static async executeQuery(dbName: string, sql: string, params: any[] = []): Promise<any> {
    const pool = this.getPool();
    const conn = await pool.getConnection();
    try {
      await conn.query(`USE \`${dbName}\`;`);
      const [results] = await conn.query(sql, params);
      return results;
    } finally {
      conn.release();
    }
  }
}
