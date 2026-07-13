import { Request, Response } from 'express';
import { createPortForwardRule, deletePortForwardRule, listPortForwardRules, updatePortForwardRule } from '../services/portForwardService.js';

export async function listRulesController(_req: Request, res: Response) {
  try {
    const rules = await listPortForwardRules();
    res.json({ success: true, data: rules });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message || 'Failed to list port forward rules.' });
  }
}

export async function createRuleController(req: Request, res: Response) {
  try {
    const rule = await createPortForwardRule(req.body);
    res.status(201).json({ success: true, data: rule });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error.message || 'Failed to create rule.' });
  }
}

export async function updateRuleController(req: Request, res: Response) {
  try {
    const rule = await updatePortForwardRule(req.params.id, req.body);
    res.json({ success: true, data: rule });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error.message || 'Failed to update rule.' });
  }
}

export async function deleteRuleController(req: Request, res: Response) {
  try {
    const rule = await deletePortForwardRule(req.params.id);
    res.json({ success: true, data: rule });
  } catch (error: any) {
    res.status(400).json({ success: false, error: error.message || 'Failed to delete rule.' });
  }
}
