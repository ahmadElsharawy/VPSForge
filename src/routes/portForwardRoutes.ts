import { Router, Express } from 'express';
import { createRuleController, deleteRuleController, listRulesController, updateRuleController } from '../controllers/portForwardController.js';

export function registerPortForwardRoutes(app: Express) {
  const router = Router();
  router.get('/api/port-forwards', listRulesController);
  router.post('/api/port-forwards', createRuleController);
  router.put('/api/port-forwards/:id', updateRuleController);
  router.delete('/api/port-forwards/:id', deleteRuleController);
  app.use(router);
}
