export const PERMISSIONS = {
  SCHOOLS_CREATE: 'schools.create',
  SCHOOLS_EDIT: 'schools.edit',
  SCHOOLS_LIFECYCLE: 'schools.lifecycle',
  SCHOOLS_PURGE: 'schools.purge',
  TENANT_ACCESS_ISSUE: 'tenant_access.issue',
  BACKUPS_DOWNLOAD: 'backups.download',
  NETWORKS_MANAGE: 'networks.manage',
} as const;

export type Permission = (typeof PERMISSIONS)[keyof typeof PERMISSIONS];

const ALL_PERMISSIONS: Permission[] = Object.values(PERMISSIONS);

const ROLE_PERMISSIONS: Record<string, Permission[]> = {
  operations_admin: [
    PERMISSIONS.SCHOOLS_CREATE,
    PERMISSIONS.SCHOOLS_EDIT,
    PERMISSIONS.SCHOOLS_LIFECYCLE,
    PERMISSIONS.TENANT_ACCESS_ISSUE,
    PERMISSIONS.BACKUPS_DOWNLOAD,
    PERMISSIONS.NETWORKS_MANAGE,
  ],
  network_admin: [PERMISSIONS.SCHOOLS_EDIT, PERMISSIONS.NETWORKS_MANAGE],
  support_agent: [PERMISSIONS.TENANT_ACCESS_ISSUE],
  finance_manager: [],
  auditor: [],
};

export function roleHasPermission(role: string, permission: Permission): boolean {
  if (role === 'superadmin') return true;
  const perms = ROLE_PERMISSIONS[role] || [];
  return perms.includes(permission);
}

export function listPermissionsForRole(role: string): Permission[] {
  if (role === 'superadmin') return [...ALL_PERMISSIONS];
  return [...(ROLE_PERMISSIONS[role] || [])];
}
