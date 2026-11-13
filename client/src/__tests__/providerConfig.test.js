import { describe, expect, it } from 'vitest';
import { canSend, providerChannel, providerLabel, usesContentTemplate } from '../utils/providerConfig.js';

describe('provider channel and label', () => {
  it('reads the one channel, or the first of an older channels list', () => {
    expect(providerChannel({ channel: 'sms' })).toBe('SMS');
    expect(providerChannel({ channels: ['SMS'] })).toBe('SMS');
    expect(providerChannel({})).toBeUndefined();
  });

  it('labels a provider as ID (CHANNEL) for the picker', () => {
    expect(providerLabel({ id: 'TWILIO', 'display-name': 'Twilio', channel: 'SMS' })).toBe('TWILIO (SMS)');
    expect(providerLabel({ id: 'TWILIO' })).toBe('TWILIO');
  });

  it('SMS and WhatsApp providers can both send', () => {
    expect(canSend({ channel: 'SMS' })).toBe(true);
    expect(canSend({ channel: 'WHATSAPP' })).toBe(true);
    expect(canSend({ channel: 'EMAIL' })).toBe(false);
    expect(canSend({})).toBe(false);
  });

  it('detects a WhatsApp Content Template provider by its ContentVariables field', () => {
    expect(usesContentTemplate({ request: { body: { fields: { ContentVariables: '{{text}}' } } } })).toBe(true);
    expect(usesContentTemplate({ request: { body: { fields: { Body: '{{text}}' } } } })).toBe(false);
    expect(usesContentTemplate({})).toBe(false);
  });
});
