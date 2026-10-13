import { Router, Request, Response, NextFunction } from 'express';
import { MasterDb } from '../db/master-db';
import { verifyTotp } from '../services/totp';
import { MailService } from '../services/mail-service';
import { config } from '../config';

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

function completeLogin(req: Request, res: Response, username: string, role: string): void {
  req.session.regenerate((err) => {
    if (err) {
      console.error('[Auth] Session regeneration failed:', err);
      return res.render('login', {
        error: 'Unable to start a session. Please try again.',
      });
    }
    (req.session as any).isAuthenticated = true;
    (req.session as any).user = { username, role };
    return res.redirect('/');
  });
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
  res.render('login', {
    error: req.query.error || null,
    success: req.query.success || null,
    magicLinkUrl: null,
    activeTab: req.query.tab === 'magic' ? 'magic' : 'password',
  });
});

router.post('/login', async (req: Request, res: Response) => {
  const key = throttleKey(req);
  if (isBlocked(key)) {
    return res.status(429).render('login', {
      error: 'Too many failed login attempts. Please try again later.',
      success: null,
      magicLinkUrl: null,
      activeTab: 'password',
    });
  }

  const { username, password } = req.body;

  const admin = await MasterDb.authenticateAdmin(username, password);
  if (admin) {
    clearFailures(key);
    if (admin.mfaSecret) {
      (req.session as any).pendingMfaUser = { username: admin.username, role: admin.role };
      return res.redirect('/auth/mfa');
    }
    completeLogin(req, res, admin.username, admin.role);
    return;
  }

  recordFailure(key);
  return res.render('login', {
    error: 'Invalid master credentials. Please try again.',
    success: null,
    magicLinkUrl: null,
    activeTab: 'password',
  });
});

router.post('/magic-link', async (req: Request, res: Response) => {
  const rawEmail = (req.body?.email || '').toString().toLowerCase().trim();
  if (!rawEmail || !rawEmail.includes('@')) {
    return res.render('login', {
      error: 'Please enter a valid administrator email address.',
      success: null,
      magicLinkUrl: null,
      activeTab: 'magic',
    });
  }

  const ip = req.ip || req.socket.remoteAddress || 'unknown';
  const key = `magic|${ip}|${rawEmail}`;
  if (isBlocked(key)) {
    return res.status(429).render('login', {
      error: 'Too many requests. Please wait a few minutes before requesting another link.',
      success: null,
      magicLinkUrl: null,
      activeTab: 'magic',
    });
  }

  const created = await MasterDb.createMagicLink(rawEmail);
  if (!created) {
    recordFailure(key);
    return res.render('login', {
      error: `No active master administrator account found for "${rawEmail}".`,
      success: null,
      magicLinkUrl: null,
      activeTab: 'magic',
    });
  }

  clearFailures(key);

  const proto = req.secure || req.headers['x-forwarded-proto'] === 'https' ? 'https' : 'http';
  const host = req.headers['x-forwarded-host'] || req.headers.host || config.masterDomain;
  const magicLink = `${proto}://${host}/auth/magic-login?token=${created.token}`;

  const mailResult = await MailService.sendMagicLoginEmail({
    to: rawEmail,
    username: created.link.email,
    magicLink,
  });

  return res.render('login', {
    error: null,
    success: mailResult.sent
      ? `A secure sign-in link has been sent to ${rawEmail}. Please check your mailbox!`
      : `A magic sign-in link has been generated for ${rawEmail}.`,
    magicLinkUrl: mailResult.sent ? null : magicLink,
    activeTab: 'magic',
  });
});

router.get('/magic-login', async (req: Request, res: Response) => {
  const token = ((req.query.token as string) || '').trim();
  if (!token) {
    return res.render('login', {
      error: 'Missing sign-in token.',
      success: null,
      magicLinkUrl: null,
      activeTab: 'magic',
    });
  }

  const ip = req.ip || req.socket.remoteAddress || 'unknown';
  const user = await MasterDb.verifyMagicLinkToken(token, ip);
  if (!user) {
    return res.render('login', {
      error: 'This magic sign-in link has expired or has already been used. Please request a new one.',
      success: null,
      magicLinkUrl: null,
      activeTab: 'magic',
    });
  }

  if (user.mfaSecret) {
    (req.session as any).pendingMfaUser = { username: user.username, role: user.role };
    return res.redirect('/auth/mfa');
  }

  completeLogin(req, res, user.username, user.role);
});

router.get('/mfa', (req: Request, res: Response) => {
  if ((req.session as any)?.isAuthenticated) {
    return res.redirect('/');
  }
  const pending = (req.session as any)?.pendingMfaUser;
  if (!pending) {
    return res.redirect('/auth/login');
  }
  res.render('mfa', { error: null });
});

router.post('/mfa', async (req: Request, res: Response) => {
  const pending = (req.session as any)?.pendingMfaUser;
  if (!pending) {
    return res.redirect('/auth/login');
  }

  const { code } = req.body;
  const user = await MasterDb.getAdminUserByUsername(pending.username);
  if (!user || !user.mfaSecret) {
    return res.redirect('/auth/login');
  }

  if (verifyTotp(user.mfaSecret, code)) {
    (req.session as any).pendingMfaUser = null;
    completeLogin(req, res, user.username, user.role);
    return;
  }

  return res.render('mfa', { error: 'Invalid verification code. Please try again.' });
});

router.get('/logout', (req: Request, res: Response) => {
  req.session.destroy(() => {
    res.redirect('/auth/login');
  });
});

export default router;
