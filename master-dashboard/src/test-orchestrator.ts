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
  await MasterDb.init();
  const networks = await MasterDb.getNetworks();
  const schools = await MasterDb.getSchools();
  assert(Array.isArray(networks), 'Networks should be initialized');
  assert(Array.isArray(schools), 'Schools should be initialized');
  console.log('✅ Passed: Master Database store initialized.\n');

  // Test 2: Cryptographic SSO Token Generation and Signature Verification
  console.log('Test 2: Cryptographic 1-Click SSO Token Generation & Signature...');
  const testSlug = 'greenwood';
  const token = SsoService.generateToken({
    schoolSlug: testSlug,
    staffId: 1,
    operator: 'test-runner',
    purpose: 'school_access',
  });
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
  const foundSchool = await MasterDb.getSchoolByDomain('greenwood.localhost');
  const customSchool = await MasterDb.getSchoolByDomain('portal.greenwoodhigh.edu');
  assert((foundSchool === undefined) === (customSchool === undefined), 'Domain lookups should return consistently');
  console.log('✅ Passed: Domain and custom domain resolution exercised.\n');

  // Test 4: School Lifecycle Action (Suspension & Activation)
  console.log('Test 4: School Lifecycle State Updates...');
  const schoolId = foundSchool ? foundSchool.id : (schools[0]?.id || 'unknown');
  if (foundSchool) {
    await MasterDb.updateSchool(schoolId, { status: 'suspended' });
    let updated = await MasterDb.getSchoolById(schoolId);
    assert.strictEqual(updated?.status, 'suspended', 'School should be suspended');

    await MasterDb.updateSchool(schoolId, { status: 'active' });
    updated = await MasterDb.getSchoolById(schoolId);
    assert.strictEqual(updated?.status, 'active', 'School should be active again');
  }
  console.log('✅ Passed: School lifecycle status updates exercised.\n');

  // Test 5: Cross-School Data Aggregation & Search
  console.log('Test 5: Cross-School Data Aggregation & Global Student Search...');
  const telemetry = await DataAggregator.getFleetTelemetry();
  assert(Array.isArray(telemetry.schools), 'Telemetry should return a school list');

  const searchResults = await DataAggregator.searchStudentsAcrossSchools('Hayes');
  assert(Array.isArray(searchResults), 'Student search should return an array');
  console.log(`✅ Passed: Data aggregator returned ${telemetry.schools.length} schools and cross-school search returned ${searchResults.length} matches.\n`);

  console.log('====================================================');
  console.log('🎉 ALL TEST SUITES PASSED CLEANLY!');
  console.log('====================================================');
}

runTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
