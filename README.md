# Smart School Multi-Tenant Cloud Platform & Fleet Control Plane

Enterprise-grade multi-tenant SaaS architecture for Smart School. Deploys isolated school instances with automated database provisioning, 1-click super-admin impersonation without passwords, cross-school data aggregation, and multi-network custom domain routing with automated SSL.

---

## Architecture Highlights

1. **1-Click Master Admin Login (SSO)**:
   - Built-in cryptographic HMAC-SHA256 token verification in Smart School base (`Site.php -> sso_login`).
   - One click from the Master Dashboard logs you directly into any school's admin panel without entering passwords.

2. **Master Data Aggregator & Cross-Verification**:
   - Live census of enrolled students, teachers, and collected fees across all schools.
   - Cross-school search: query students and parents by admission number, name, or phone across all campus databases.
   - Central payment reconciliation ledger.

3. **Multi-Network & Custom Domains**:
   - Organize schools under parent networks (e.g. `*.yournetwork.com`, `*.groupofschools.org`).
   - Bind dedicated custom domains (`portal.school.edu`) with automated Let's Encrypt certificates via Caddy On-Demand TLS.

4. **100% Tenant Isolation (Approach 2)**:
   - Dedicated database per school (`ss_tenant_{slug}`).
   - Dedicated container per school (`ss_tenant_{slug}`).
   - Dedicated upload volume per school (`./tenants/{slug}/uploads`).

---

## Deploying on Easypanel

Because **Easypanel** already includes a built-in Traefik reverse proxy and 1-click database services, deploying is fast and straightforward:

### Step 1: Create MariaDB Service in Easypanel
1. Inside your Easypanel project, click **"+ Service"** -> **"Database"** -> **"MariaDB"**.
2. Set the database root password (e.g. `smartschool_root_pass`) and database name `ss_master_orchestrator`.
3. Note the internal host name (usually `mariadb` or `mariadb:3306`).

### Step 2: Deploy Master Dashboard Service
1. In the same project, click **"+ Service"** -> **"App"**.
2. Connect your GitHub repository:
   - **Build type**: Dockerfile
   - **Dockerfile path**: `master-dashboard/Dockerfile`
   - **Context path**: `master-dashboard`
3. Under **Environment**, add:
   ```env
   NODE_ENV=production
   PORT=3000
   MASTER_ADMIN_USER=superadmin
   MASTER_ADMIN_PASS=MasterAdmin2026!
   MASTER_SSO_SECRET=ss-master-orchestrator-secret-key-2026
   FLEET_DB_HOST=mariadb
   FLEET_DB_PORT=3306
   FLEET_DB_USER=root
   FLEET_DB_PASSWORD=your_mariadb_password
   MASTER_DB_NAME=ss_master_orchestrator
   DOCKER_NETWORK=easypanel
   ```
4. Under **Mounts / Volumes**, add:
   - Host path: `/var/run/docker.sock` -> Container path: `/var/run/docker.sock` (gives control plane Docker API access)
   - Host path: `/etc/easypanel/projects/your-project/tenants` -> Container path: `/var/www/html/tenants`
5. Under **Domains**, attach your master control domain:
   - e.g., `master.yourdomain.com` (Easypanel will automatically issue Let's Encrypt SSL via Traefik).

---

## Standalone Server Deployment (Docker Compose)

For running on any standard Ubuntu 22.04 / 24.04 server:

```bash
git clone <your-repo-url> smartschool
cd smartschool
./deploy.sh
```

- **Master Dashboard**: `http://<your-server-ip>:3000`
- **Default Username**: `superadmin`
- **Default Password**: `MasterAdmin2026!`
- **phpMyAdmin**: `http://<your-server-ip>:8081`

---

## Directory Structure

```
.
├── application/                # Smart School PHP 8.2 base (de-licensed + SSO enabled)
├── master-dashboard/           # Central Network Control Plane (Express + TypeScript + Tailwind)
│   ├── src/
│   │   ├── db/                 # Master store & MariaDB seeder
│   │   ├── services/           # SSO token generator, Docker API, Data Aggregator, DNS check
│   │   ├── routes/             # Master auth, schools, analytics, networks, Caddy webhook
│   │   └── views/              # Tailwind UI templates
├── caddy/                      # Caddy reverse proxy with On-Demand TLS
├── tenants/                    # Isolated tenant filesystem storage
├── docker-compose.master.yml   # Full production orchestration stack
├── deploy.sh                   # Automated deployment script
└── Dockerfile                  # Smart School base image
```
