import { describe, expect, it } from 'vitest';
import { PROVIDER_EXAMPLE } from '../utils/providerConfig.js';
import {
  validateBody,
  validatePhone,
  validateProviderConfig,
} from '../utils/validation.js';

describe('validatePhone', () => {
  it('accepts E.164 numbers', () => {
    expect(validatePhone('+910000000001')).toBeNull();
    expect(validatePhone(' +10000000001 ')).toBeNull();
  });
  it('rejects non E.164 numbers', () => {
    for (const bad of ['', '910000000001', '+0123456789', '+1234567', '+1234567890123456', '+91 00000 00001']) {
      expect(validatePhone(bad)).not.toBeNull();
    }
  });
});

describe('validateBody', () => {
  it('requires 1 to 1600 characters', () => {
    expect(validateBody('')).not.toBeNull();
    expect(validateBody('   ')).not.toBeNull();
    expect(validateBody('a'.repeat(1600))).toBeNull();
    expect(validateBody('a'.repeat(1601))).toMatch(/1 characters over/);
  });
});

describe('validateProviderConfig', () => {
  it('accepts the documented registration example', () => {
    expect(validateProviderConfig(PROVIDER_EXAMPLE).problems).toEqual([]);
  });

  it('reports missing request and response like the backend', () => {
    const { problems } = validateProviderConfig({ id: 'X', 'display-name': 'X', channel: 'SMS' });
    expect(problems).toContain('request is missing');
    expect(problems).toContain('response is missing');
  });

  it('needs one channel, SMS or WHATSAPP', () => {
    const problemsFor = (patch) => {
      const { channel: _c, ...rest } = PROVIDER_EXAMPLE;
      return validateProviderConfig({ ...rest, ...patch }).problems;
    };
    expect(problemsFor({ channel: 'SMS' })).toEqual([]);
    expect(problemsFor({ channel: 'sms' })).toEqual([]);
    expect(problemsFor({ channel: 'WHATSAPP' })).toEqual([]);
    expect(problemsFor({ channel: 'whatsapp' })).toEqual([]);
    expect(problemsFor({})).toEqual(['channel is missing, for example "SMS"']);
    expect(problemsFor({ channels: ['SMS'] })).toEqual(['Use "channel": "SMS" (one value) instead of "channels"']);
    expect(problemsFor({ channel: 'EMAIL' })).toEqual(['channel "EMAIL" is not supported. Use one of: SMS, WHATSAPP.']);
  });

  it('rejects bad ids, env placeholders, auth types and body formats', () => {
    const cfg = {
      ...PROVIDER_EXAMPLE,
      id: 'bad id!',
      variables: { token: '${PLIVO_TOKEN}' },
      request: { url: 'https://x', auth: { type: 'oauth' }, body: { format: 'xml' } },
    };
    const { problems } = validateProviderConfig(cfg);
    expect(problems.some((p) => p.startsWith('id may contain'))).toBe(true);
    expect(problems.some((p) => p.includes('environment placeholder'))).toBe(true);
    expect(problems.some((p) => p.startsWith('request.auth.type'))).toBe(true);
    expect(problems.some((p) => p.startsWith('request.body.format'))).toBe(true);
  });

  it('rejects placeholders used as variable values', () => {
    const cfg = { ...PROVIDER_EXAMPLE, variables: { ...PROVIDER_EXAMPLE.variables, 'auth-id': '{{auth-id}}' } };
    expect(validateProviderConfig(cfg).problems).toContain('variables.auth-id is a placeholder. Enter the real value.');
  });

  it('allows masked secrets on update but not on create', () => {
    const cfg = { ...PROVIDER_EXAMPLE, variables: { ...PROVIDER_EXAMPLE.variables, 'auth-token': '****' } };
    expect(validateProviderConfig(cfg, { mode: 'create' }).problems.some((p) => p.includes('masked'))).toBe(true);
    expect(validateProviderConfig(cfg, { mode: 'update', pathId: 'PLIVO' }).problems).toEqual([]);
  });

  it('requires the update id to match the path id, case-insensitively, or be omitted', () => {
    expect(validateProviderConfig({ ...PROVIDER_EXAMPLE, id: 'plivo' }, { mode: 'update', pathId: 'PLIVO' }).problems).toEqual([]);
    const { id, ...withoutId } = PROVIDER_EXAMPLE;
    expect(id).toBe('plivo');
    expect(validateProviderConfig(withoutId, { mode: 'update', pathId: 'PLIVO' }).problems).toEqual([]);
    expect(validateProviderConfig(PROVIDER_EXAMPLE, { mode: 'update', pathId: 'OTHER' }).problems).toHaveLength(1);
  });

});
