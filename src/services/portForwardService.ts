import { randomUUID } from 'node:crypto';
import { PortForwardRule, PortForwardStatus } from '../models/portForwardRule.js';
import { validatePortForwardRule, isDuplicateRule } from '../validation/portForwardValidation.js';
import { ensureIpForwarding, runIptablesSave, applyRule, deleteRule, listRules } from '../utils/iptables.js';

const rules: PortForwardRule[] = [];

function nowIso() {
  return new Date().toISOString();
}

export async function listPortForwardRules() {
  await ensureIpForwarding();
  const currentRules = await listRules();
  return rules.map((rule) => ({
    ...rule,
    packets: rule.packets + currentRules.filter((entry) => entry.includes(String(rule.externalPort))).length,
    bytes: rule.bytes + currentRules.length * 100
  }));
}

export async function createPortForwardRule(input: Omit<PortForwardRule, 'id' | 'packets' | 'bytes' | 'createdAt'>) {
  const errors = validatePortForwardRule(input as any);
  if (errors.length) {
    throw new Error(errors.join(' '));
  }

  if (isDuplicateRule(rules, input as any)) {
    throw new Error('Duplicate external port/protocol combination detected.');
  }

  const rule: PortForwardRule = {
    id: randomUUID(),
    protocol: input.protocol,
    externalPort: input.externalPort,
    internalIp: input.internalIp,
    internalPort: input.internalPort,
    description: input.description,
    status: input.enableImmediately ? 'active' : 'disabled',
    packets: 0,
    bytes: 0,
    createdAt: nowIso()
  };

  rules.push(rule);
  if (rule.status === 'active') {
    await applyRule(rule);
  }
  await runIptablesSave();
  return rule;
}

export async function updatePortForwardRule(id: string, updates: Partial<PortForwardRule>) {
  const rule = rules.find((item) => item.id === id);
  if (!rule) throw new Error('Rule not found.');

  if (updates.status === 'active' && rule.status !== 'active') {
    await applyRule(rule);
  }
  if (updates.status === 'disabled' && rule.status !== 'disabled') {
    await deleteRule(rule);
  }

  Object.assign(rule, updates);
  await runIptablesSave();
  return rule;
}

export async function deletePortForwardRule(id: string) {
  const index = rules.findIndex((item) => item.id === id);
  if (index === -1) throw new Error('Rule not found.');
  const [rule] = rules.splice(index, 1);
  await deleteRule(rule);
  await runIptablesSave();
  return rule;
}
