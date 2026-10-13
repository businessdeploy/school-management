"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OperationsService = void 0;
const master_repository_1 = require("../db/master-repository");
class OperationsService {
    static async start(type, schoolId, idempotencyKey, operator) {
        const now = new Date().toISOString();
        const id = `op_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
        await master_repository_1.MasterRepository.createOperation({
            id,
            type,
            schoolId,
            idempotencyKey,
            status: 'running',
            operator,
            createdAt: now,
            updatedAt: now,
        });
        return id;
    }
    static async runStep(operationId, step, fn) {
        const now = new Date().toISOString();
        const stepId = await master_repository_1.MasterRepository.addOperationStep({
            operationId,
            step,
            status: 'running',
            createdAt: now,
            updatedAt: now,
        });
        try {
            await fn();
            await master_repository_1.MasterRepository.updateOperationStep(stepId, 'succeeded');
        }
        catch (err) {
            await master_repository_1.MasterRepository.updateOperationStep(stepId, 'failed', err.message || String(err));
            throw err;
        }
    }
    static async finish(operationId, status) {
        await master_repository_1.MasterRepository.updateOperationStatus(operationId, status);
    }
    static async list() {
        return master_repository_1.MasterRepository.listOperations();
    }
}
exports.OperationsService = OperationsService;
