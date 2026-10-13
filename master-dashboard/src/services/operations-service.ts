import { MasterRepository } from '../db/master-repository';
import { OperationRecord, OperationStatus } from '../db/master-db';

export class OperationsService {
  static async start(
    type: string,
    schoolId: string | undefined,
    idempotencyKey: string | undefined,
    operator: string | undefined
  ): Promise<string> {
    const now = new Date().toISOString();
    const id = `op_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    await MasterRepository.createOperation({
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

  static async runStep(operationId: string, step: string, fn: () => Promise<void>): Promise<void> {
    const now = new Date().toISOString();
    const stepId = await MasterRepository.addOperationStep({
      operationId,
      step,
      status: 'running',
      createdAt: now,
      updatedAt: now,
    });
    try {
      await fn();
      await MasterRepository.updateOperationStep(stepId, 'succeeded');
    } catch (err: any) {
      await MasterRepository.updateOperationStep(stepId, 'failed', err.message || String(err));
      throw err;
    }
  }

  static async finish(operationId: string, status: OperationStatus): Promise<void> {
    await MasterRepository.updateOperationStatus(operationId, status);
  }

  static async list(): Promise<OperationRecord[]> {
    return MasterRepository.listOperations();
  }

  /**
   * Marks operations that have been stuck in a running state past the
   * threshold as failed (crash recovery for interrupted workers).
   */
  static async recoverStaleOperations(maxAgeMs = 10 * 60 * 1000): Promise<number> {
    const before = new Date(Date.now() - maxAgeMs).toISOString();
    return MasterRepository.markStaleRunningOperationsFailed(before);
  }
}
