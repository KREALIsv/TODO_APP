export type MailFlowName = 'welcome' | 'password_reset' | 'vault_recovery';

export interface SendMailParams {
  to: string;
  subject: string;
  html: string;
  flow: MailFlowName;
  userId?: string;
}

export interface MailSendResult {
  id?: string;
  skipped?: boolean;
  reason?: string;
}
