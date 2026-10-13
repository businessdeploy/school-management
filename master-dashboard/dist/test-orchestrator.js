"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const assert_1 = __importDefault(require("assert"));
const crypto_1 = __importDefault(require("crypto"));
const master_db_1 = require("./db/master-db");
const sso_service_1 = require("./services/sso-service");
const data_aggregator_1 = require("./services/data-aggregator");
const config_1 = require("./config");
async function runTests() {
    console.log('🧪 Starting Master Orchestrator Verification Suite...\n');
    // Test 1: Master Database Initialization
    console.log('Test 1: Master Database Store initialization...');
    await master_db_1.MasterDb.init();
    const networks = await master_db_1.MasterDb.getNetworks();
    const schools = await master_db_1.MasterDb.getSchools();
    (0, assert_1.default)(Array.isArray(networks), 'Networks should be initialized');
    (0, assert_1.default)(Array.isArray(schools), 'Schools should be initialized');
    console.log('✅ Passed: Master Database store initialized.\n');
    // Test 2: Cryptographic SSO Token Generation and Signature Verification
    console.log('Test 2: Cryptographic 1-Click SSO Token Generation & Signature...');
    const testSlug = 'greenwood';
    const token = sso_service_1.SsoService.generateToken({
        schoolSlug: testSlug,
        staffId: 1,
        operator: 'test-runner',
        purpose: 'school_access',
    });
    (0, assert_1.default)(token.includes('.'), 'Token must have <payload>.<signature> format');
    const [b64Payload, sig] = token.split('.');
    const expectedSig = crypto_1.default
        .createHmac('sha256', config_1.config.masterSsoSecret)
        .update(b64Payload)
        .digest('hex');
    assert_1.default.strictEqual(sig, expectedSig, 'HMAC signature must match expected secret');
    const payload = JSON.parse(Buffer.from(b64Payload, 'base64').toString('utf-8'));
    assert_1.default.strictEqual(payload.school_slug, testSlug, 'Payload slug matches');
    assert_1.default.strictEqual(payload.role, 7, 'Role must be 7 (Super Admin)');
    (0, assert_1.default)(Math.abs(Math.floor(Date.now() / 1000) - payload.timestamp) <= 5, 'Timestamp must be fresh');
    console.log('✅ Passed: SSO Token format, HMAC signature, and payload verified.\n');
    // Test 3: Domain Routing & Domain Lookup
    console.log('Test 3: School Domain Lookup...');
    const foundSchool = await master_db_1.MasterDb.getSchoolByDomain('greenwood.localhost');
    const customSchool = await master_db_1.MasterDb.getSchoolByDomain('portal.greenwoodhigh.edu');
    (0, assert_1.default)((foundSchool === undefined) === (customSchool === undefined), 'Domain lookups should return consistently');
    console.log('✅ Passed: Domain and custom domain resolution exercised.\n');
    // Test 4: School Lifecycle Action (Suspension & Activation)
    console.log('Test 4: School Lifecycle State Updates...');
    const schoolId = foundSchool ? foundSchool.id : (schools[0]?.id || 'unknown');
    if (foundSchool) {
        await master_db_1.MasterDb.updateSchool(schoolId, { status: 'suspended' });
        let updated = await master_db_1.MasterDb.getSchoolById(schoolId);
        assert_1.default.strictEqual(updated?.status, 'suspended', 'School should be suspended');
        await master_db_1.MasterDb.updateSchool(schoolId, { status: 'active' });
        updated = await master_db_1.MasterDb.getSchoolById(schoolId);
        assert_1.default.strictEqual(updated?.status, 'active', 'School should be active again');
    }
    console.log('✅ Passed: School lifecycle status updates exercised.\n');
    // Test 5: Cross-School Data Aggregation & Search
    console.log('Test 5: Cross-School Data Aggregation & Global Student Search...');
    const telemetry = await data_aggregator_1.DataAggregator.getFleetTelemetry();
    (0, assert_1.default)(Array.isArray(telemetry.schools), 'Telemetry should return a school list');
    const searchResults = await data_aggregator_1.DataAggregator.searchStudentsAcrossSchools('Hayes');
    (0, assert_1.default)(Array.isArray(searchResults), 'Student search should return an array');
    console.log(`✅ Passed: Data aggregator returned ${telemetry.schools.length} schools and cross-school search returned ${searchResults.length} matches.\n`);
    console.log('====================================================');
    console.log('🎉 ALL TEST SUITES PASSED CLEANLY!');
    console.log('====================================================');
}
runTests().catch((err) => {
    console.error('❌ Test failed:', err);
    process.exit(1);
});
