export type PortForwardProtocol = 'TCP' | 'UDP' | 'BOTH';
export type PortForwardStatus = 'active' | 'disabled';

export interface PortForwardRule {
  id: string;
  protocol: PortForwardProtocol;
  externalIp?: string;
  externalPort: number;
  internalIp: string;
  internalPort: number;
  description: string;
  status: PortForwardStatus;
  packets: number;
  bytes: number;
  createdAt: string;
}
