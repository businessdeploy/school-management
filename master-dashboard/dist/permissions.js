"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ROLES = exports.PERMISSIONS = void 0;
exports.roleHasPermission = roleHasPermission;
exports.listPermissionsForRole = listPermissionsForRole;
exports.PERMISSIONS = {
    SCHOOLS_CREATE: 'schools.create',
    SCHOOLS_EDIT: 'schools.edit',
    SCHOOLS_LIFECYCLE: 'schools.lifecycle',
    SCHOOLS_PURGE: 'schools.purge',
    TENANT_ACCESS_ISSUE: 'tenant_access.issue',
    BACKUPS_DOWNLOAD: 'backups.download',
    NETWORKS_MANAGE: 'networks.manage',
    USERS_MANAGE: 'users.manage',
};
exports.ROLES = [
    'superadmin',
    'operations_admin',
    'network_admin',
    'support_agent',
    'finance_manager',
    'auditor',
];
const ALL_PERMISSIONS = Object.values(exports.PERMISSIONS);
const ROLE_PERMISSIONS = {
    operations_admin: [
        exports.PERMISSIONS.SCHOOLS_CREATE,
        exports.PERMISSIONS.SCHOOLS_EDIT,
        exports.PERMISSIONS.SCHOOLS_LIFECYCLE,
        exports.PERMISSIONS.TENANT_ACCESS_ISSUE,
        exports.PERMISSIONS.BACKUPS_DOWNLOAD,
        exports.PERMISSIONS.NETWORKS_MANAGE,
    ],
    network_admin: [exports.PERMISSIONS.SCHOOLS_EDIT, exports.PERMISSIONS.NETWORKS_MANAGE],
    support_agent: [exports.PERMISSIONS.TENANT_ACCESS_ISSUE],
    finance_manager: [],
    auditor: [],
};
function roleHasPermission(role, permission) {
    if (role === 'superadmin')
        return true;
    const perms = ROLE_PERMISSIONS[role] || [];
    return perms.includes(permission);
}
function listPermissionsForRole(role) {
    if (role === 'superadmin')
        return [...ALL_PERMISSIONS];
    return [...(ROLE_PERMISSIONS[role] || [])];
}
