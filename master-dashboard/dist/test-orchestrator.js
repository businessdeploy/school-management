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
    master_db_1.MasterDb.init();
    const networks = master_db_1.MasterDb.getNetworks();
    const schools = master_db_1.MasterDb.getSchools();
    (0, assert_1.default)(networks.length > 0, 'Networks should be initialized');
    (0, assert_1.default)(schools.length > 0, 'Initial schools should be present in store');
    console.log('✅ Passed: Master Database store initialized with defaults.\n');
    // Test 2: Cryptographic SSO Token Generation and Signature Verification
    console.log('Test 2: Cryptographic 1-Click SSO Token Generation & Signature...');
    const testSlug = 'greenwood';
    const token = sso_service_1.SsoService.generateToken(testSlug, 1);
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
    const foundSchool = master_db_1.MasterDb.getSchoolByDomain('greenwood.localhost');
    (0, assert_1.default)(foundSchool !== undefined, 'Should find school by subdomain');
    assert_1.default.strictEqual(foundSchool?.slug, 'greenwood', 'Found school slug matches');
    const customSchool = master_db_1.MasterDb.getSchoolByDomain('portal.greenwoodhigh.edu');
    (0, assert_1.default)(customSchool !== undefined, 'Should find school by custom domain');
    console.log('✅ Passed: Domain and custom domain resolution verified.\n');
    // Test 4: School Lifecycle Action (Suspension & Activation)
    console.log('Test 4: School Lifecycle State Updates...');
    const schoolId = foundSchool.id;
    master_db_1.MasterDb.updateSchool(schoolId, { status: 'suspended' });
    let updated = master_db_1.MasterDb.getSchoolById(schoolId);
    assert_1.default.strictEqual(updated?.status, 'suspended', 'School should be suspended');
    master_db_1.MasterDb.updateSchool(schoolId, { status: 'active' });
    updated = master_db_1.MasterDb.getSchoolById(schoolId);
    assert_1.default.strictEqual(updated?.status, 'active', 'School should be active again');
    console.log('✅ Passed: School lifecycle status updates verified.\n');
    // Test 5: Cross-School Data Aggregation & Search
    console.log('Test 5: Cross-School Data Aggregation & Global Student Search...');
    const telemetry = await data_aggregator_1.DataAggregator.getFleetTelemetry();
    (0, assert_1.default)(telemetry.totalStudents > 0, 'Total students should be aggregated');
    (0, assert_1.default)(telemetry.totalStaff > 0, 'Total staff should be aggregated');
    const searchResults = await data_aggregator_1.DataAggregator.searchStudentsAcrossSchools('Hayes');
    (0, assert_1.default)(searchResults.length > 0, 'Student search for Hayes should return records');
    (0, assert_1.default)(searchResults.some((s) => s.admissionNo.includes('GW') || s.admissionNo.includes('DPS')), 'Should match across schools');
    console.log(`✅ Passed: Data aggregator reported ${telemetry.totalStudents} students and cross-school search returned ${searchResults.length} matches.\n`);
    console.log('====================================================');
    console.log('🎉 ALL 5 TEST SUITES PASSED CLEANLY!');
    console.log('====================================================');
}
runTests().catch((err) => {
    console.error('❌ Test failed:', err);
    process.exit(1);
});
