"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const data_aggregator_1 = require("../services/data-aggregator");
const router = (0, express_1.Router)();
router.get('/', async (req, res) => {
    const searchQuery = (req.query.search || '').trim();
    const telemetry = await data_aggregator_1.DataAggregator.getFleetTelemetry();
    let searchResults = [];
    if (searchQuery) {
        searchResults = await data_aggregator_1.DataAggregator.searchStudentsAcrossSchools(searchQuery);
    }
    const recentPayments = await data_aggregator_1.DataAggregator.getRecentCrossSchoolPayments();
    res.render('master-data', {
        pageTitle: 'Master Data & Cross-Verification Command',
        telemetry,
        searchQuery,
        searchResults,
        recentPayments,
    });
});
exports.default = router;
