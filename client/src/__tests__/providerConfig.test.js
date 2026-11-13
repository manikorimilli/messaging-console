import { describe, expect, it } from 'vitest';
import { providerChannel, providerLabel, supportsSms } from '../utils/providerConfig.js';

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

  it('only SMS providers can send for now', () => {
    expect(supportsSms({ channel: 'SMS' })).toBe(true);
    expect(supportsSms({ channel: 'WHATSAPP' })).toBe(false);
  });
});
