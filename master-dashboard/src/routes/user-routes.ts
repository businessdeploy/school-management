import { Router, Request, Response } from 'express';
import { MasterDb } from '../db/master-db';
import { ROLES } from '../permissions';

const router = Router();

router.get('/', async (req: Request, res: Response) => {
  const users = await MasterDb.listAdminUsers();
  res.render('users', {
    pageTitle: 'Users & Access',
    users,
    roles: ROLES,
    error: req.query.error || null,
    success: req.query.success || null,
  });
});

router.post('/create', async (req: Request, res: Response) => {
  const { username, password, displayName, role } = req.body;

  const cleanUsername = (username || '').trim();
  if (!cleanUsername) {
    return res.redirect('/users?error=' + encodeURIComponent('Username is required.'));
  }
  if (!password || String(password).length < 6) {
    return res.redirect('/users?error=' + encodeURIComponent('Password must be at least 6 characters.'));
  }
  if (!(ROLES as readonly string[]).includes(role)) {
    return res.redirect('/users?error=' + encodeURIComponent('Invalid role.'));
  }

  const existing = await MasterDb.getAdminUserByUsername(cleanUsername);
  if (existing) {
    return res.redirect('/users?error=' + encodeURIComponent(`Username "${cleanUsername}" is already taken.`));
  }

  try {
    await MasterDb.createAdminUser({
      username: cleanUsername,
      password: String(password),
      displayName: displayName ? String(displayName).trim() : undefined,
      role,
    });
    res.redirect('/users?success=' + encodeURIComponent(`User "${cleanUsername}" created.`));
  } catch (err: any) {
    console.error('[User Create Error]:', err);
    res.redirect('/users?error=' + encodeURIComponent('Failed to create user.'));
  }
});

router.post('/:id/toggle-active', async (req: Request, res: Response) => {
  const user = await MasterDb.getAdminUserById(req.params.id);
  if (!user) return res.redirect('/users');

  const currentUsername = (req.session as any)?.user?.username;
  if (user.username === currentUsername) {
    return res.redirect('/users?error=' + encodeURIComponent('You cannot deactivate your own account.'));
  }

  const nextActive = !user.isActive;
  if (!nextActive && user.role === 'superadmin') {
    const activeSuperadmins = (await MasterDb.listAdminUsers()).filter((u) => u.role === 'superadmin' && u.isActive);
    if (activeSuperadmins.length <= 1) {
      return res.redirect('/users?error=' + encodeURIComponent('Cannot deactivate the last active superadmin.'));
    }
  }

  await MasterDb.setAdminUserActive(user.id, nextActive);
  res.redirect('/users?success=' + encodeURIComponent(`User "${user.username}" ${nextActive ? 'activated' : 'deactivated'}.`));
});

export default router;
