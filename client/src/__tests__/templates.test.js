import { describe, expect, it } from 'vitest';
import { GENERAL_TEMPLATES, TWILIO_TEMPLATES, templatesForProvider } from '../data/sampleTemplates.js';

describe('templatesForProvider', () => {
  it('uses the Twilio test values for any Twilio provider', () => {
    expect(templatesForProvider('TWILIO')).toBe(TWILIO_TEMPLATES);
    expect(templatesForProvider('twilio2')).toBe(TWILIO_TEMPLATES);
    // Registered under any id: recognised by its Twilio address.
    const myTwilio = { id: 'MY-SMS', request: { url: 'https://api.twilio.com/2010-04-01/Accounts/{{account-sid}}/Messages.json' } };
    expect(templatesForProvider(myTwilio)).toBe(TWILIO_TEMPLATES);
  });
  it('keeps the free-text samples for other providers', () => {
    expect(templatesForProvider('VONAGE')).toBe(GENERAL_TEMPLATES);
    expect(templatesForProvider({ id: 'VONAGE', request: { url: 'https://rest.nexmo.com/sms/json' } })).toBe(GENERAL_TEMPLATES);
    // A look-alike address is not Twilio.
    expect(templatesForProvider({ id: 'X', request: { url: 'https://api.twilio.com.evil.test/send' } })).toBe(GENERAL_TEMPLATES);
  });
  it('offers nothing until a provider is chosen', () => {
    expect(templatesForProvider(undefined)).toEqual([]);
    expect(templatesForProvider('')).toEqual([]);
  });
  it('sends the exact Twilio body values', () => {
    expect(TWILIO_TEMPLATES.map((t) => t.text)).toEqual([
      'sms_2fa',
      'sms_appointment_reminders',
      'sms_order_confirmation',
      'sms_delivery_updates',
      'sms_customer_support',
      'sms_marketing_promotions',
      'sms_event_notifications',
      'sms_account_alerts',
      'sms_feedback_surveys',
      'sms_internal_alerts',
    ]);
  });
});
