import assert from 'assert';
import crypto from 'crypto';
import { MasterDb } from './db/master-db';
import { SsoService } from './services/sso-service';
import { DataAggregator } from './services/data-aggregator';
import { config } from './config';

async function runTests() {
  console.log('🧪 Starting Master Orchestrator Verification Suite...\n');

  // Test 1: Master Database Initialization
  console.log('Test 1: Master Database Store initialization...');
  MasterDb.init();
  const networks = MasterDb.getNetworks();
  const schools = MasterDb.getSchools();
  assert(networks.length > 0, 'Networks should be initialized');
  assert(schools.length > 0, 'Initial schools should be present in store');
  console.log('✅ Passed: Master Database store initialized with defaults.\n');

  // Test 2: Cryptographic SSO Token Generation and Signature Verification
  console.log('Test 2: Cryptographic 1-Click SSO Token Generation & Signature...');
  const testSlug = 'greenwood';
  const token = SsoService.generateToken(testSlug, 1);
  assert(token.includes('.'), 'Token must have <payload>.<signature> format');

  const [b64Payload, sig] = token.split('.');
  const expectedSig = crypto
    .createHmac('sha256', config.masterSsoSecret)
    .update(b64Payload)
    .digest('hex');

  assert.strictEqual(sig, expectedSig, 'HMAC signature must match expected secret');

  const payload = JSON.parse(Buffer.from(b64Payload, 'base64').toString('utf-8'));
  assert.strictEqual(payload.school_slug, testSlug, 'Payload slug matches');
  assert.strictEqual(payload.role, 7, 'Role must be 7 (Super Admin)');
  assert(Math.abs(Math.floor(Date.now() / 1000) - payload.timestamp) <= 5, 'Timestamp must be fresh');
  console.log('✅ Passed: SSO Token format, HMAC signature, and payload verified.\n');

  // Test 3: Domain Routing & Domain Lookup
  console.log('Test 3: School Domain Lookup...');
  const foundSchool = MasterDb.getSchoolByDomain('greenwood.localhost');
  assert(foundSchool !== undefined, 'Should find school by subdomain');
  assert.strictEqual(foundSchool?.slug, 'greenwood', 'Found school slug matches');

  const customSchool = MasterDb.getSchoolByDomain('portal.greenwoodhigh.edu');
  assert(customSchool !== undefined, 'Should find school by custom domain');
  console.log('✅ Passed: Domain and custom domain resolution verified.\n');

  // Test 4: School Lifecycle Action (Suspension & Activation)
  console.log('Test 4: School Lifecycle State Updates...');
  const schoolId = foundSchool!.id;
  MasterDb.updateSchool(schoolId, { status: 'suspended' });
  let updated = MasterDb.getSchoolById(schoolId);
  assert.strictEqual(updated?.status, 'suspended', 'School should be suspended');

  MasterDb.updateSchool(schoolId, { status: 'active' });
  updated = MasterDb.getSchoolById(schoolId);
  assert.strictEqual(updated?.status, 'active', 'School should be active again');
  console.log('✅ Passed: School lifecycle status updates verified.\n');

  // Test 5: Cross-School Data Aggregation & Search
  console.log('Test 5: Cross-School Data Aggregation & Global Student Search...');
  const telemetry = await DataAggregator.getFleetTelemetry();
  assert(telemetry.totalStudents > 0, 'Total students should be aggregated');
  assert(telemetry.totalStaff > 0, 'Total staff should be aggregated');

  const searchResults = await DataAggregator.searchStudentsAcrossSchools('Hayes');
  assert(searchResults.length > 0, 'Student search for Hayes should return records');
  assert(searchResults.some((s) => s.admissionNo.includes('GW') || s.admissionNo.includes('DPS')), 'Should match across schools');
  console.log(`✅ Passed: Data aggregator reported ${telemetry.totalStudents} students and cross-school search returned ${searchResults.length} matches.\n`);

  console.log('====================================================');
  console.log('🎉 ALL 5 TEST SUITES PASSED CLEANLY!');
  console.log('====================================================');
}

runTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
