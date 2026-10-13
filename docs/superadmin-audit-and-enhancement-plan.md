# Superadmin Panel Audit and Enhancement Plan

12 October 2026

The Smart School master panel should become a reliable management console for schools, clients, networks, subscriptions, and platform operations. The first release should correct unsafe tenant access and misleading operational data before expanding management features. Preserve the existing school application and add platform controls around it.

## Scope and evidence

This is a source audit of `master-dashboard/src`, its EJS screens, deployment configuration, and the PHP tenant database selection, SSO receiver, and fee model. Findings describe the current checkout. Production reachability, deployed configuration, visual usability, and actual tenant data require separate staging verification; no live system was changed. This is not an exhaustive audit of the school application or mobile API.

The plan treats “superadmin” primarily as the central fleet administrator. School-level superadmins continue to manage admissions, academics, staff, fees, attendance, and other existing school modules. Platform access must be scoped independently from the PHP school's existing RBAC.

## Existing capabilities

| Area | Implemented capability | Management gap |
| --- | --- | --- |
| Overview | School, student, staff, collection, and outstanding cards | No reliable freshness or unavailable-data state; fallback figures can appear as real data |
| Schools | Create, list, inspect, edit settings, assign quotas, start, stop, restart, suspend, activate, remove | No durable jobs, enforced quotas, lifecycle reconciliation, archive workflow, or comprehensive server validation |
| Tenant access | Signed SSO link and password reset | No operator-specific permission, reason, replay consumption, or tenant binding at the receiver |
| Networks and domains | Add networks, check DNS, bind custom domains, certificate authorization endpoint | No complete edit/archive workflow, ownership verification, unique domain constraint, or observed certificate status |
| Master data | Cross-school student search and recent fee ledger | No role or school scope, pagination across the fleet, reliable error disclosure, or correct payment aggregation |
| Backups | Download a generated database SQL dump | No scheduled database plus uploads backup, restore workflow, retention, or demonstrated restore integrity |
| Clients | Client record type, demo seed, association during onboarding | No dedicated client management routes or lifecycle screens |
| Plans | Starter, Pro, Enterprise labels on clients | No subscription lifecycle, pricing, invoices, payment state, or plan enforcement |

## Priority audit findings

P0 means urgent security remediation. P1 means a correctness or management requirement for the next usable release. P2 means subsequent enhancement. These priorities reflect code impact, not proof of exploitation in production.

| ID | Priority | Finding and evidence | Required change |
| --- | --- | --- | --- |
| A01 | P0 | Public tenant proxy failure generates and displays a signed staff login link. Tenant routing executes before master authentication. See `services/gateway-proxy.ts:123` and `index.ts:34`. A public requester can receive a privileged token when that failure branch executes. | Remove token generation from public responses; return an escaped, generic 503. Mint tenant access grants only after master authentication and a specific access permission. |
| A02 | P0 | Known fallback credentials and shared secrets exist in `config.ts:14`, the PHP SSO receiver, and Compose. Startup logs print the master password (`index.ts:133`). `services/easypanel-service.ts:2` contains a credential-bearing default endpoint. | Remove credential defaults and logging; require production secrets. Replace the embedded endpoint with injected configuration. Rotate any deployed values that used these defaults or the embedded credential. Do not reproduce secrets in tickets or audit records. |
| A03 | P0 | The PHP SSO receiver validates signature and a 120-second timestamp window, but does not compare `school_slug` with the resolved tenant or consume the nonce (`application/controllers/Site.php:1002`). A common secret and matching staff ID allow a valid grant to be presented to another school. | Bind grants to tenant, recipient, operator, and purpose; consume each grant once; reject excessive future timestamps and inactive targets. Record the master operator separately from the target staff account. |
| A04 | P1 | Master auth is one environment-configured account with an authenticated boolean (`routes/auth-routes.ts:7`). No roles, scoped permissions, MFA, login throttling, or session regeneration appear in this flow. Sessions use the default memory store and `secure: false` (`index.ts:44`). No CSRF checks appear in the master middleware or forms. | Introduce named users, hashed passwords, MFA, persistent sessions, login throttling, HTTPS cookies with an explicit SameSite policy, session rotation, and CSRF protection for mutations. |
| A05 | P1 | Password reset includes the new password in a redirect URL (`routes/school-routes.ts:249`). The update targets `id = 1 OR employee_id = '9000' OR email = ?`, potentially changing several accounts (`db/fleet-db.ts:133`). SSO URLs are also written to logs. | Remove passwords and tokens from URLs, logs, and messages. Store an explicit administrator staff ID; check role, status, and exactly one affected row. Revoke sessions after reset through the school authentication path. |
| A06 | P1 | Onboarding can return from seeding with no database, swallow setup failures, ignore false Docker/domain results, and still mark the school active (`db/seed-installer.ts:33`, `routes/school-routes.ts:123`). Docker reports running/success when unavailable. | Require verified completion of each stage; make failure visible. Add durable, retryable provisioning jobs and a reconciliation worker. Emulation must require explicit demo mode and must never report production success. |
| A07 | P1 | Visiting school screens calls `syncLiveDomain` with Host or forwarded Host. It rewrites school subdomains across networks (`db/master-db.ts:121`). Domain binding and editing mark SSL active without certificate confirmation. The TLS authorization endpoint permits any subdomain under a stored network (`routes/caddy-routes.ts:33`). | Reads must not mutate routing. Use configured master hosts, explicit network assignments, unique domains, ownership checks, and observed DNS/routing/certificate states. Restrict certificate issuance to approved domain records. |
| A08 | P1 | Master records live in a process-local JSON store with direct writes. Save errors are logged without failing the action; malformed input triggers default reseeding (`db/master-db.ts:80`, `db/master-db.ts:225`). | Move records to transactional master tables, with unique keys, foreign keys, migrations, backups, and explicit write failures. Preserve and quarantine a corrupt source store instead of overwriting it. |
| A09 | P1 | Telemetry substitutes sample data on outages. Collections sum JSON text; outstanding remains zero in the successful live path. The ledger joins `d.student_fees_id`, absent from the bundled deposit table (`services/data-aggregator.ts:91,280`, `database.sql:4925`). | Remove automatic sample fallback. Parse payment detail entries consistently with the PHP fee model, use actual fee/session relationships, compute dues, and expose partial coverage. Validate against school reports with fixtures. |
| A10 | P1 | Start/stop/status routes can update metadata despite Docker returning false. General edit accepts arbitrary status. Deletion removes the container and record, leaving database/uploads and no recovery record (`routes/school-routes.ts:275,311,372`). | Separate requested business status from observed runtime health. Use validated transitions, durable operations, typed confirmation for destructive actions, archive retention, and an explicit later purge job. |
| A11 | P1 | The gateway routes tenants to one `PHP_BACKEND_URL`, while provisioning creates dedicated containers. PHP selects databases from tenant headers; created containers receive the fleet DB credentials (`services/gateway-proxy.ts:116`, `application/config/database.php:83`, `services/docker-service.ts:65`). | Choose and document the deployment model. For the advertised isolated model, route to the school's container, give it a tenant-only DB user, and keep PHP inaccessible outside the trusted gateway. Verify uploads, sessions, and backups are isolated. Direct header spoofing risk depends on backend exposure. |
| A12 | P1 | Limits are stored/displayed, with no enforcement found for `storageQuotaGb` or `maxStudents`. Validation is mostly form attributes or simple parsing. Custom domains and identifiers lack central constraints. | Add shared server validation, valid client/network references, bounded integer limits, domain normalization and uniqueness, reserved slug checks, and admission/upload enforcement. Never trust browser validation. |
| A13 | P1 | SQL download reads every table into application memory without a consistent snapshot. It covers neither uploads nor a tested restore procedure (`db/fleet-db.ts:164`). | Use a background consistent database backup and uploads manifest; encrypt, checksum, store off-host, and verify restores into an isolated environment. |
| A14 | P1 | The global error page interpolates raw messages/stacks; tenant pages interpolate stored school fields into HTML (`index.ts:117`, `services/gateway-proxy.ts:56`). | Escape rendered values, show a reference ID to users, and keep redacted diagnostics server-side. Test stored markup and crafted error values. |

Additional delivery concerns: the header always displays “Fleet Mesh: Online”; the master Dockerfile does not copy `public` assets; most async Express 4 handlers have no explicit error forwarding; the existing verification script mutates the master store and depends on demo records. Replace these with measured health, complete artifact packaging, consistent error handling, and isolated tests.

## Proposed management navigation

| Menu | Management options | Priority |
| --- | --- | --- |
| Overview | Health summary, active/suspended schools, failed jobs, expiring domains, overdue backups, usage alerts, recent administrative actions | P1 |
| Schools | Search/filter/pagination, create wizard, owner/network reassignment, configuration, health, quota usage, controlled lifecycle, archive and restore | P1 |
| Clients and Organizations | Create/edit/archive clients, contacts, ownership, associated schools, account state, internal notes | P1 |
| Users and Access | Invitations, named accounts, role templates, school/network scopes, MFA, active sessions, access review | P1 |
| Networks and Domains | Network edit/archive, domain claim verification, binding/unbinding, DNS diagnostics, certificate status and expiry | P1 |
| Backups and Recovery | Schedule, retention, database and uploads coverage, download access, restore preview, restore history | P1 |
| Jobs and Operations | Provision/retry/cancel where safe, restart progress, maintenance windows, fleet reconciliation, operation history | P1 |
| Reports | Scoped census and fee reports, session/date/currency filters, source timestamp, completeness, controlled exports | P1 |
| Audit and Approvals | Operator/action/target filters, before/after changes, failed actions, reasons, approvals, protected audit export | P1 |
| Plans and Subscriptions | Plan catalog, entitlements, trial/renewal state, usage, grace periods, manual billing records first | P2 |
| Support and Notices | Tickets, internal notes, time-limited school access, maintenance announcements, delivery history | P2 |
| Platform Settings | Branding, locale, integration health, notification settings, backup policies, secret rotation metadata | P2 |

School detail tabs: Summary, Configuration, Users and Access, Domains, Usage, Reports, Backups, Operations, and Audit. Summary shows business status, application health, database health, last successful backup, and last checked time separately. Keep archive/purge controls in a distinct restricted area.

List screens should use saved filters, clear empty/error/loading states, server pagination, and keyboard-accessible controls. The current fixed-width sidebar should become collapsible on small screens. Actions show their impact, required reason, progress, and result; unavailable integrations disable dependent actions with an explanation.

## Role and permission model

| Proposed role | Default access | Restricted actions |
| --- | --- | --- |
| Platform Owner | Platform configuration, user administration, all school scopes, approval authority | Sensitive actions still require recent authentication and an audit reason |
| Operations Admin | Provisioning, domains, health, maintenance and backups in assigned scopes | No billing changes, user-role escalation, or unilateral permanent purge |
| Network Admin | Assigned networks and schools, approved configuration and aggregate reports | No other networks, platform secrets, host operations, or default bulk personal-data export |
| Support Agent | Assigned tickets, health, limited diagnostics | School impersonation requires a separate approved grant; no default backup download or reset |
| Finance Manager | Subscription records and authorized fee summaries | No runtime control, secret access, or default student record access |
| Auditor | Read-only scoped audit and approved reports | No changes, impersonation, or password resets |

Use explicit permissions such as `schools.create`, `schools.suspend`, `tenant_access.issue`, `backups.download`, `backups.restore`, `reports.personal_data`, and `schools.purge`. Check permissions and resource scope on every server request and worker command. Hiding a button is insufficient. Deny unassigned access by default.

## Required workflows

### School onboarding and lifecycle

1. Select a valid client, network, locale, and plan; validate slug, domain, limits, and administrator identity.
2. Preview the configuration and create an operation with an idempotency key.
3. Provision the database/user, schema, tenant storage, administrator, runtime, and route in recorded stages.
4. Verify application/database access and expected administrator role before marking the school ready.
5. On failure, preserve stage diagnostics and offer safe retry or explicit cleanup. Retrying must not recreate accounts, overwrite data, or duplicate domain routes.

Model business state separately from runtime state. Suspension blocks public access according to policy; stopping the runtime does not silently alter subscription state. Archive disables access and preserves the recovery record. Purge is a separate, delayed operation with a dependency preview covering DB, files, routes, backups, and retention obligations.

### School access and password recovery

Choose the school and target staff identity, enter a support reason, and require recent authentication. Issue a one-time grant for that tenant with a short lifetime. Record the operator and grant result; show an impersonation banner and an exit action in the school session. Support grants should be read-only where the school application can enforce that scope. Owner exceptions remain explicit and audited.

Prefer an expiring recovery invitation for password changes. A direct reset must target one authorized account, avoid displaying the password afterward, and invalidate existing sessions.

### Domain changes

Normalize and reserve the domain, verify ownership through a challenge, check DNS, register routing, then observe certificate issuance. States are Pending ownership, Pending DNS, Provisioning route, Pending certificate, Active, and Failed. Preserve the old working route until replacement verification succeeds. Unbind and reassignment require an impact preview; visiting a school list must never change domains.

### Backups and restore

Back up database plus uploads with school ID, schema/app version, timestamps, checksums, and encryption metadata. Record the destination and outcome. Restore first into an isolated destination, check record counts and files, and allow an authorized cutover after validation. Keep pre-restore recovery material and a rollback path. Proposed starting targets are a 24-hour recovery point and a four-hour recovery time, subject to school requirements, data volume, and a measured restore drill.

### Reports and quota enforcement

Display unavailable/partial values instead of sample totals. Report active enrollment by academic session and date; distinguish principal, discount, fine, refund, and outstanding amounts. Follow the deposit-to-fee-master-to-student-session relationship, with the separate transport-fee relationship where applicable. Keep school currencies separate unless an explicit conversion policy exists. Do not count school fee collections as platform subscription revenue.

Measure database and upload storage separately. Define whether student limits use active enrollment or another count. Warn at configurable thresholds and enforce at admission/import/upload entry points; reads remain available. Block unsafe downgrades without a clear resolution path and record any temporary override.

## Implementation architecture

Keep Express/TypeScript/EJS and CodeIgniter initially. Add policy checks, validation, and orchestration services so route handlers no longer decide operational success independently.

Use the existing master MariaDB deployment for transactional metadata. Proposed tables are `admin_users`, `roles`, `permissions`, `role_permissions`, `user_scopes`, `sessions`, `clients`, `networks`, `schools`, `tenant_admin_accounts`, `domains`, `plans`, `subscriptions`, `operations`, `operation_steps`, `backup_runs`, `restore_runs`, `usage_snapshots`, `audit_events`, `access_grants`, and `notifications`. Add tickets and approval records when their workflows ship. Protect secret values outside ordinary settings tables.

Use a durable worker queue, initially a database-backed operations table if that meets measured capacity. Add bounded retries, timeouts, per-school operation locks, heartbeat/recovery, and idempotency. A reconciliation worker compares requested state with database, runtime, route, and certificate observations. Limit the worker's Docker and provisioning privileges; web-facing code should submit authorized commands rather than expose general host control.

Migrate JSON through a validated import with duplicate/domain checks, row counts, an archived original, and rollback instructions. Avoid a long-running dual-write period. Separate provisioning DB privileges from tenant runtime users and reporting credentials. Logs and audit records must redact credentials, grants, and unnecessary student data; restrict audit modification and define retention before enabling exports.

## Delivery plan

| Phase | Deliverable | Exit condition | Indicative effort |
| --- | --- | --- | --- |
| 0 | Remove public SSO issuance, credential defaults/logs, password URL disclosure; enforce tenant-bound single-use SSO | Public backend outage exposes no grant; cross-tenant and replay tests fail closed; configured secrets replace defaults | 2–4 engineering days |
| 1 | Named users, permissions/scopes, sessions, CSRF, validation, audit trail, transactional master store | Unauthorized and out-of-scope requests fail; sessions and records survive restart; migration reconciles | 1–2 weeks |
| 2 | Durable onboarding/lifecycle jobs, clients, school search, reliable domain state and runtime routing | Failed integrations never produce active/success status; retries are safe; each school routes to its intended runtime | 2–3 weeks |
| 3 | Accurate reports, quota enforcement, scheduled backups and tested restore, health alerts | Fixtures reconcile with school reports; DB outage shows partial/unavailable; backup restore meets agreed targets | 2–3 weeks |
| 4 | Subscription management, support workflow, controlled notices, fleet update/rollback | Entitlements are enforced; operational actions and access grants remain scoped and audited | 2–4 weeks |

These are planning ranges for a small experienced team, not commitments. Phase 0 can begin immediately. Staging access, representative tenant schemas, deployment-model confirmation, restore storage, and product policy decisions affect the schedule. Phases 0–3 form the first complete management release; advanced billing integrations and fleet upgrades follow it.

## Acceptance and verification

Use an isolated master database, temporary storage, and fake or dedicated staging adapters. Do not run the current `test-orchestrator.ts` against production records because it changes school status and assumes seeded demo schools.

| Area | Required acceptance test |
| --- | --- |
| Public gateway | Backend failure returns a generic error without SSO links, tokens, credentials, or tenant database identifiers |
| Tenant access | Missing auth/permission, wrong tenant, expired grant, reused grant, and inactive staff are rejected; authorized access records the operator |
| Master access | Login throttling, session regeneration/revocation, MFA, CSRF, and scope checks work for every mutation and sensitive read |
| Persistence | Corrupt source metadata is preserved; write failures fail actions; duplicate slugs/domains are rejected; restart retains state |
| Provisioning | DB, seed, Docker, and domain failure simulations yield explicit failed stages; retry does not duplicate or overwrite resources |
| Lifecycle | Runtime failure cannot report success; concurrent actions serialize; unknown schools do not return success |
| Domains | Host/forwarded Host cannot rewrite stored routes; unknown or unverified domains cannot obtain authorization; certificate failure stays visible |
| Isolation | A tenant cannot access another DB, upload path, session, or backup; PHP accepts routing identity only from the trusted ingress |
| Reports | JSON deposits, transport fees, discounts, fines, refunds, multiple currencies, empty schools, and outages produce expected scoped results |
| Quotas | Direct API, bulk admission/import, and upload paths enforce limits with understandable errors and audited overrides |
| Recovery | Database plus uploads restore into a clean destination, checksum/count validation passes, and rollback is demonstrated |
| Interface | Small-screen navigation, keyboard operation, focus handling, pagination, and loading/empty/error states work; all bundled assets load |

Release through staging, then a small pilot fleet. Verify migrated metadata, routing, permissions, and a recovery drill before extending to all schools. Monitor failed operations, unknown health, backup age, and audit gaps. Rollback must restore both compatible application code and master metadata.

## Product decisions to settle during implementation

Recommended defaults are a central platform superadmin with scoped network admins, dedicated tenant runtime/DB users, archive before purge, manual subscription records before payment automation, and all school student data hidden from support unless separately authorized.

Confirm the actual deployment model and routing before Phase 2. Agree who may impersonate school administrators, which roles may export personal data, how quotas behave during renewal or downgrade, and how long archived schools and backups are retained. Specify currency and academic-session reporting rules before Phase 3. These decisions refine implementation; they do not delay the urgent access and disclosure fixes.
