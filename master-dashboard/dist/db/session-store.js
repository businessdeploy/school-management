"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DbSessionStore = void 0;
const express_session_1 = __importDefault(require("express-session"));
const config_1 = require("../config");
const fleet_db_1 = require("./fleet-db");
const DEFAULT_TTL_MS = 86400000;
function sessionExpiry(sess) {
    if (sess?.cookie?.expires) {
        const t = new Date(sess.cookie.expires).getTime();
        if (!Number.isNaN(t))
            return t;
    }
    return Date.now() + (sess?.cookie?.maxAge || DEFAULT_TTL_MS);
}
/**
 * MariaDB-backed session store so master sessions survive process restarts.
 */
class DbSessionStore extends express_session_1.default.Store {
    constructor() {
        super();
    }
    query(sql, params = []) {
        return fleet_db_1.FleetDb.executeQuery(config_1.config.fleetDb.masterDatabase, sql, params);
    }
    get(sid, callback) {
        this.query('SELECT session_data, expires_at FROM sessions WHERE sid = ? LIMIT 1', [sid])
            .then((rows) => {
            if (!rows || rows.length === 0) {
                return callback(null, null);
            }
            const row = rows[0];
            if (Number(row.expires_at) < Date.now()) {
                return this.query('DELETE FROM sessions WHERE sid = ?', [sid]).then(() => callback(null, null));
            }
            try {
                return callback(null, JSON.parse(row.session_data));
            }
            catch (err) {
                return callback(err);
            }
        })
            .catch((err) => callback(err));
    }
    set(sid, sess, callback) {
        const expiresAt = sessionExpiry(sess);
        this.query(`INSERT INTO sessions (sid, session_data, expires_at)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE session_data = VALUES(session_data), expires_at = VALUES(expires_at)`, [sid, JSON.stringify(sess), expiresAt])
            .then(() => callback && callback(null))
            .catch((err) => callback && callback(err));
    }
    destroy(sid, callback) {
        this.query('DELETE FROM sessions WHERE sid = ?', [sid])
            .then(() => callback && callback(null))
            .catch((err) => callback && callback(err));
    }
    touch(sid, sess, callback) {
        this.query('UPDATE sessions SET expires_at = ? WHERE sid = ?', [sessionExpiry(sess), sid])
            .then(() => callback && callback(null))
            .catch((err) => callback && callback(err));
    }
}
exports.DbSessionStore = DbSessionStore;
