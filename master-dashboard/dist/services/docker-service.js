"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DockerService = void 0;
const dockerode_1 = __importDefault(require("dockerode"));
const fs_1 = __importDefault(require("fs"));
const config_1 = require("../config");
class DockerService {
    static docker = null;
    static isAvailable = false;
    static init() {
        try {
            const socketPath = process.platform === 'win32' ? '//./pipe/docker_engine' : '/var/run/docker.sock';
            if (fs_1.default.existsSync(socketPath)) {
                this.docker = new dockerode_1.default({ socketPath });
                this.isAvailable = true;
                console.log('[DockerService] Connected to local Docker socket:', socketPath);
            }
            else {
                console.log('[DockerService] Docker socket not detected at', socketPath, '- Running in Cloud / Emulation mode');
                this.isAvailable = false;
            }
        }
        catch (err) {
            this.isAvailable = false;
            console.warn('[DockerService] Docker initialization warning:', err);
        }
    }
    static async checkContainerStatus(containerName) {
        if (!this.docker || !this.isAvailable)
            return 'running'; // Emulated default
        try {
            const container = this.docker.getContainer(containerName);
            const data = await container.inspect();
            return data?.State?.Running ? 'running' : 'stopped';
        }
        catch (err) {
            return 'not_found';
        }
    }
    static async launchTenantContainer(options) {
        if (!this.docker || !this.isAvailable) {
            console.log(`[DockerService] (Emulation) Launched container: ${options.containerName}`);
            return true;
        }
        try {
            const existing = this.docker.getContainer(options.containerName);
            try {
                await existing.stop();
                await existing.remove();
            }
            catch (e) {
                // Ignored if doesn't exist
            }
            const memoryLimit = (options.ramLimitMb || 512) * 1024 * 1024;
            const tenantUploadPath = `${config_1.config.tenantsStoragePath}/${options.slug}/uploads`;
            const tenantBackupPath = `${config_1.config.tenantsStoragePath}/${options.slug}/backup`;
            const container = await this.docker.createContainer({
                Image: config_1.config.tenantDockerImage,
                name: options.containerName,
                Env: [
                    `DB_HOST=${config_1.config.fleetDb.host}`,
                    `DB_NAME=${options.dbName}`,
                    `DB_USER=${config_1.config.fleetDb.user}`,
                    `DB_PASS=${config_1.config.fleetDb.password}`,
                    `BASE_URL=https://${options.domain}/`,
                    `MASTER_SSO_SECRET=${config_1.config.masterSsoSecret}`,
                    'INSTALLED=true',
                ],
                HostConfig: {
                    NetworkMode: config_1.config.dockerNetwork,
                    RestartPolicy: { Name: 'unless-stopped' },
                    Memory: memoryLimit,
                    Binds: [
                        `${tenantUploadPath}:/var/www/html/uploads`,
                        `${tenantBackupPath}:/var/www/html/backup`,
                    ],
                },
            });
            await container.start();
            console.log(`[DockerService] Successfully started container: ${options.containerName}`);
            return true;
        }
        catch (err) {
            console.error(`[DockerService] Failed to launch container ${options.containerName}:`, err);
            return false;
        }
    }
    static async stopContainer(containerName) {
        if (!this.docker || !this.isAvailable)
            return true;
        try {
            const container = this.docker.getContainer(containerName);
            await container.stop();
            return true;
        }
        catch (err) {
            console.error(`[DockerService] Error stopping container ${containerName}:`, err);
            return false;
        }
    }
    static async startContainer(containerName) {
        if (!this.docker || !this.isAvailable)
            return true;
        try {
            const container = this.docker.getContainer(containerName);
            await container.start();
            return true;
        }
        catch (err) {
            console.error(`[DockerService] Error starting container ${containerName}:`, err);
            return false;
        }
    }
    static async restartContainer(containerName) {
        if (!this.docker || !this.isAvailable)
            return true;
        try {
            const container = this.docker.getContainer(containerName);
            await container.restart();
            return true;
        }
        catch (err) {
            console.error(`[DockerService] Error restarting container ${containerName}:`, err);
            return false;
        }
    }
    static async removeContainer(containerName) {
        if (!this.docker || !this.isAvailable)
            return true;
        try {
            const container = this.docker.getContainer(containerName);
            try {
                await container.stop();
            }
            catch (e) { }
            await container.remove({ force: true });
            return true;
        }
        catch (err) {
            console.error(`[DockerService] Error removing container ${containerName}:`, err);
            return false;
        }
    }
    static async getLogs(containerName, tail = 100) {
        if (!this.docker || !this.isAvailable) {
            return `[Docker Emulation] Logs for ${containerName}:\n[${new Date().toISOString()}] Apache/2.4.59 (Debian) PHP/8.2.18 configured -- resuming normal operations\n[${new Date().toISOString()}] Command line: 'apache2 -D FOREGROUND'\n[${new Date().toISOString()}] Container healthy, responding to internal proxy.`;
        }
        try {
            const container = this.docker.getContainer(containerName);
            try {
                const inspect = await container.inspect();
                if (!inspect || !inspect.State) {
                    return `Container '${containerName}' is offline or initializing.`;
                }
            }
            catch (inspectErr) {
                return `Container '${containerName}' has not been deployed to Docker engine yet or is stopped.`;
            }
            const logs = await container.logs({
                stdout: true,
                stderr: true,
                tail,
                timestamps: true,
                follow: false,
            });
            if (Buffer.isBuffer(logs)) {
                return logs.toString('utf-8');
            }
            else if (typeof logs === 'string') {
                return logs;
            }
            return 'Container is running (no output recorded yet).';
        }
        catch (err) {
            return `Container logs unavailable: ${err.message || err}`;
        }
    }
}
exports.DockerService = DockerService;
