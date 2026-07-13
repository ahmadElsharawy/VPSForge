import { isIP } from 'node:net';
import { PortForwardProtocol, PortForwardRule } from '../models/portForwardRule.js';

export interface CreateRuleInput {
  protocol: PortForwardProtocol;
  externalIp?: string;
  externalPort: number;
  internalIp: string;
  internalPort: number;
  description: string;
  enableImmediately: boolean;
}

export function validatePortForwardRule(input: CreateRuleInput) {
  const errors: string[] = [];

  if (!['TCP', 'UDP', 'BOTH'].includes(input.protocol)) {
    errors.push('Protocol must be TCP, UDP, or BOTH.');
  }

  if (!Number.isInteger(input.externalPort) || input.externalPort < 1 || input.externalPort > 65535) {
    errors.push('External port must be between 1 and 65535.');
  }

  if (input.externalIp && !isIP(input.externalIp)) {
    errors.push('External IP must be a valid IPv4 address when provided.');
  }

  if (!Number.isInteger(input.internalPort) || input.internalPort < 1 || input.internalPort > 65535) {
    errors.push('Internal port must be between 1 and 65535.');
  }

  if (!isIP(input.internalIp)) {
    errors.push('Internal IP must be a valid IPv4 address.');
  }

  if (input.description.length > 200) {
    errors.push('Description must be 200 characters or less.');
  }

  return errors;
}

export function isDuplicateRule(rules: PortForwardRule[], input: CreateRuleInput) {
  return rules.some((rule) =>
    rule.protocol === input.protocol &&
    rule.externalPort === input.externalPort &&
    (rule.externalIp || '') === (input.externalIp || '')
  );
}
