import { describe, expect, it } from 'vitest';
import { TWILIO_TEMPLATES, templatesForProvider } from '../data/sampleTemplates.js';

describe('templatesForProvider', () => {
  it('uses the Twilio test values for any provider, any channel', () => {
    expect(templatesForProvider('TWILIO')).toBe(TWILIO_TEMPLATES);
    expect(templatesForProvider('twilio2')).toBe(TWILIO_TEMPLATES);
    expect(templatesForProvider('VONAGE')).toBe(TWILIO_TEMPLATES);
    const twilioWhatsApp = {
      id: 'TWILIO',
      channel: 'WHATSAPP',
      request: { url: 'https://api.twilio.com/2010-04-01/Accounts/{{account-sid}}/Messages.json', body: { fields: { Body: '{{text}}' } } },
    };
    expect(templatesForProvider(twilioWhatsApp)).toBe(TWILIO_TEMPLATES);
  });
  it('offers nothing until a provider is chosen', () => {
    expect(templatesForProvider(undefined)).toEqual([]);
    expect(templatesForProvider('')).toEqual([]);
  });
  it('offers no samples for a WhatsApp Content Template provider', () => {
    const contentTemplateProvider = {
      id: 'TWILIO_WA',
      channel: 'WHATSAPP',
      request: { url: 'https://api.twilio.com/2010-04-01/Accounts/{{account-sid}}/Messages.json', body: { fields: { ContentVariables: '{{text}}' } } },
    };
    expect(templatesForProvider(contentTemplateProvider)).toEqual([]);
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
