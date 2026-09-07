import { Router, Request, Response, NextFunction } from 'express';
import { config } from '../config';

const router = Router();

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

router.post('/login', (req: Request, res: Response) => {
  const { username, password } = req.body;

  if (username === config.masterAdminUsername && password === config.masterAdminPassword) {
    (req.session as any).isAuthenticated = true;
    (req.session as any).user = { username, role: 'Network Super Admin' };
    return res.redirect('/');
  }

  return res.render('login', { error: 'Invalid master credentials. Please try again.' });
});

router.get('/logout', (req: Request, res: Response) => {
  req.session.destroy(() => {
    res.redirect('/auth/login');
  });
});

export default router;
