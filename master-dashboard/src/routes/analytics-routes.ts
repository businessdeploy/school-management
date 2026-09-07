import { Router, Request, Response } from 'express';
import { DataAggregator } from '../services/data-aggregator';

const router = Router();

router.get('/', async (req: Request, res: Response) => {
  const searchQuery = (req.query.search as string || '').trim();
  const telemetry = await DataAggregator.getFleetTelemetry();

  let searchResults = [];
  if (searchQuery) {
    searchResults = await DataAggregator.searchStudentsAcrossSchools(searchQuery);
  }

  const recentPayments = await DataAggregator.getRecentCrossSchoolPayments();

  res.render('master-data', {
    pageTitle: 'Master Data & Cross-Verification Command',
    telemetry,
    searchQuery,
    searchResults,
    recentPayments,
  });
});

export default router;
