import { exec } from 'node:child_process';
import { promisify } from 'node:util';
import { PortForwardProtocol, PortForwardRule } from '../models/portForwardRule.js';

const execAsync = promisify(exec);

export async function ensureIpForwarding() {
  const { stdout } = await execAsync('cat /proc/sys/net/ipv4/ip_forward');
  if (stdout.trim() !== '1') {
    await execAsync('sysctl -w net.ipv4.ip_forward=1');
    await execAsync('echo net.ipv4.ip_forward=1 > /etc/sysctl.d/99-vpsforge-ip-forward.conf');
  }
}

export async function runIptablesSave() {
  try {
    await execAsync('netfilter-persistent save');
  } catch {
    await execAsync('iptables-save > /etc/iptables/rules.v4');
  }
}

export async function listRules() {
  const { stdout } = await execAsync('iptables -t nat -S');
  return stdout.split('\n').filter(Boolean);
}

function getProtocols(protocol: PortForwardRule['protocol']) {
  return protocol === 'BOTH' ? ['tcp', 'udp'] : [protocol.toLowerCase()];
}

function buildDestinationSpec(rule: PortForwardRule) {
  return rule.externalIp ? `-d ${rule.externalIp}` : '';
}

export async function applyRule(rule: PortForwardRule) {
  const protocols = getProtocols(rule.protocol);
  const commands: string[] = [];

  for (const protocol of protocols) {
    const destinationSpec = buildDestinationSpec(rule);
    commands.push(
      `iptables -t nat -A PREROUTING -p ${protocol} ${destinationSpec} --dport ${rule.externalPort} -j DNAT --to-destination ${rule.internalIp}:${rule.internalPort}`.trim(),
      `iptables -A FORWARD -p ${protocol} -d ${rule.internalIp} --dport ${rule.internalPort} -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT`,
      `iptables -A FORWARD -p ${protocol} -s ${rule.internalIp} --sport ${rule.internalPort} -m state --state ESTABLISHED,RELATED -j ACCEPT`
    );
  }

  for (const cmd of commands) {
    await execAsync(cmd);
  }
}

export async function deleteRule(rule: PortForwardRule) {
  const protocols = getProtocols(rule.protocol);
  const commands: string[] = [];

  for (const protocol of protocols) {
    const destinationSpec = buildDestinationSpec(rule);
    commands.push(
      `iptables -t nat -D PREROUTING -p ${protocol} ${destinationSpec} --dport ${rule.externalPort} -j DNAT --to-destination ${rule.internalIp}:${rule.internalPort}`.trim(),
      `iptables -D FORWARD -p ${protocol} -d ${rule.internalIp} --dport ${rule.internalPort} -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT`,
      `iptables -D FORWARD -p ${protocol} -s ${rule.internalIp} --sport ${rule.internalPort} -m state --state ESTABLISHED,RELATED -j ACCEPT`
    );
  }

  for (const cmd of commands) {
    await execAsync(cmd);
  }
}
