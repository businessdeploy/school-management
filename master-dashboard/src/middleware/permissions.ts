import { Request, Response, NextFunction } from 'express';
import { Permission, roleHasPermission } from '../permissions';

/**
 * Rejects requests whose authenticated user role lacks the required permission.
 */
export function requirePermission(permission: Permission) {
  return (req: Request, res: Response, next: NextFunction) => {
    const role = (req.session as any)?.user?.role;
    if (!role || !roleHasPermission(role, permission)) {
      return res.status(403).send('Forbidden: insufficient permissions.');
    }
    return next();
  };
}
