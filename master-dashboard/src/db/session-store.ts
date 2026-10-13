import session from 'express-session';
import { config } from '../config';
import { FleetDb } from './fleet-db';

const DEFAULT_TTL_MS = 86400000;

function sessionExpiry(sess: any): number {
  if (sess?.cookie?.expires) {
    const t = new Date(sess.cookie.expires).getTime();
    if (!Number.isNaN(t)) return t;
  }
  return Date.now() + (sess?.cookie?.maxAge || DEFAULT_TTL_MS);
}

/**
 * MariaDB-backed session store so master sessions survive process restarts.
 */
export class DbSessionStore extends session.Store {
  constructor() {
    super();
  }

  private query(sql: string, params: any[] = []): Promise<any> {
    return FleetDb.executeQuery(config.fleetDb.masterDatabase, sql, params);
  }

  get(sid: string, callback: (err: any, session?: any) => void): void {
    this.query('SELECT session_data, expires_at FROM sessions WHERE sid = ? LIMIT 1', [sid])
      .then((rows: any[]) => {
        if (!rows || rows.length === 0) {
          return callback(null, null);
        }
        const row = rows[0];
        if (Number(row.expires_at) < Date.now()) {
          return this.query('DELETE FROM sessions WHERE sid = ?', [sid]).then(() => callback(null, null));
        }
        try {
          return callback(null, JSON.parse(row.session_data));
        } catch (err) {
          return callback(err);
        }
      })
      .catch((err) => callback(err));
  }

  set(sid: string, sess: any, callback?: (err?: any) => void): void {
    const expiresAt = sessionExpiry(sess);
    this.query(
      `INSERT INTO sessions (sid, session_data, expires_at)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE session_data = VALUES(session_data), expires_at = VALUES(expires_at)`,
      [sid, JSON.stringify(sess), expiresAt]
    )
      .then(() => callback && callback(null))
      .catch((err) => callback && callback(err));
  }

  destroy(sid: string, callback?: (err?: any) => void): void {
    this.query('DELETE FROM sessions WHERE sid = ?', [sid])
      .then(() => callback && callback(null))
      .catch((err) => callback && callback(err));
  }

  touch(sid: string, sess: any, callback?: (err?: any) => void): void {
    this.query('UPDATE sessions SET expires_at = ? WHERE sid = ?', [sessionExpiry(sess), sid])
      .then(() => callback && callback(null))
      .catch((err) => callback && callback(err));
  }
}
