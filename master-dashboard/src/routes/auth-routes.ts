import { Router, Request, Response, NextFunction } from 'express';
import { MasterDb } from '../db/master-db';

const router = Router();

const MAX_FAILED_ATTEMPTS = 5;
const ATTEMPT_WINDOW_MS = 15 * 60 * 1000;
const LOCKOUT_MS = 15 * 60 * 1000;

interface ThrottleRecord {
  attempts: number;
  firstAttemptAt: number;
  blockedUntil: number;
}

const loginThrottle = new Map<string, ThrottleRecord>();

function throttleKey(req: Request): string {
  const ip = req.ip || req.socket.remoteAddress || 'unknown';
  const username = (req.body?.username || '').toString().toLowerCase();
  return `${ip}|${username}`;
}

function isBlocked(key: string): boolean {
  const rec = loginThrottle.get(key);
  if (!rec) return false;
  if (rec.blockedUntil > Date.now()) return true;
  if (Date.now() - rec.firstAttemptAt > ATTEMPT_WINDOW_MS) {
    loginThrottle.delete(key);
  }
  return false;
}

function recordFailure(key: string): void {
  const now = Date.now();
  const rec = loginThrottle.get(key);
  if (!rec || now - rec.firstAttemptAt > ATTEMPT_WINDOW_MS) {
    loginThrottle.set(key, { attempts: 1, firstAttemptAt: now, blockedUntil: 0 });
    return;
  }
  rec.attempts += 1;
  if (rec.attempts >= MAX_FAILED_ATTEMPTS) {
    rec.blockedUntil = now + LOCKOUT_MS;
    rec.attempts = 0;
  }
}

function clearFailures(key: string): void {
  loginThrottle.delete(key);
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  if ((req.session as any)?.isAuthenticated) {
    return next();
  }
  return res.redirect('/auth/login');
}

router.get('/login', (req: Request, res: Response) => {
  if ((req.session as any)?.isAuthenticated) {
    return res.redirect('/');
  }
  res.render('login', { error: null });
});

router.post('/login', async (req: Request, res: Response) => {
  const key = throttleKey(req);
  if (isBlocked(key)) {
    return res.status(429).render('login', {
      error: 'Too many failed login attempts. Please try again later.',
    });
  }

  const { username, password } = req.body;

  const admin = await MasterDb.verifyAdminCredentials(username, password);
  if (admin) {
    clearFailures(key);
    req.session.regenerate((err) => {
      if (err) {
        console.error('[Auth] Session regeneration failed:', err);
        return res.render('login', {
          error: 'Unable to start a session. Please try again.',
        });
      }
      (req.session as any).isAuthenticated = true;
      (req.session as any).user = { username: admin.username, role: admin.role };
      return res.redirect('/');
    });
    return;
  }

  recordFailure(key);
  return res.render('login', { error: 'Invalid master credentials. Please try again.' });
});

router.get('/logout', (req: Request, res: Response) => {
  req.session.destroy(() => {
    res.redirect('/auth/login');
  });
});

export default router;
