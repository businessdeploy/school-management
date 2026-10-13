"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requirePermission = requirePermission;
const permissions_1 = require("../permissions");
/**
 * Rejects requests whose authenticated user role lacks the required permission.
 */
function requirePermission(permission) {
    return (req, res, next) => {
        const role = req.session?.user?.role;
        if (!role || !(0, permissions_1.roleHasPermission)(role, permission)) {
            return res.status(403).send('Forbidden: insufficient permissions.');
        }
        return next();
    };
}
