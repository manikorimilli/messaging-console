import { beforeEach, describe, expect, it } from 'vitest';
import * as mock from '../api/mockApi.js';
import { PROVIDER_EXAMPLE } from '../utils/providerConfig.js';

beforeEach(() => {
  mock.setMockLatency(0);
  mock.resetMockStore();
});

describe('mock providers', () => {
  it('lists providers sorted by id with secrets masked', async () => {
    const list = await mock.listProviders();
    expect(list.map((p) => p.id)).toEqual(['MSG91', 'TEXTLOCAL', 'TWILIO', 'VONAGE']);
    const twilio = list.find((p) => p.id === 'TWILIO');
    expect(twilio).toMatchObject({ channel: 'SMS', enabled: true });
    expect(twilio.variables['auth-token']).toBe('****');
    expect(twilio.variables.from).toBe('+10000000001');
  });

  it('looks up ids case-insensitively', async () => {
    await expect(mock.getProvider('twilio')).resolves.toMatchObject({ id: 'TWILIO' });
    await expect(mock.getProvider('nope')).rejects.toMatchObject({ status: 404, code: 'PROVIDER_NOT_FOUND' });
  });

  it('registers with uppercase id, rejects duplicates', async () => {
    const saved = await mock.registerProvider(PROVIDER_EXAMPLE);
    expect(saved).toMatchObject({ id: 'PLIVO', channel: 'SMS', enabled: true });
    expect(saved.variables['auth-token']).toBe('****');
    await expect(mock.registerProvider(PROVIDER_EXAMPLE)).rejects.toMatchObject({ status: 409, code: 'PROVIDER_ALREADY_EXISTS' });
  });

  it('keeps the stored secret when an update sends ****', async () => {
    await mock.registerProvider(PROVIDER_EXAMPLE);
    const fetched = await mock.getProvider('PLIVO');
    await mock.updateProvider('PLIVO', { ...fetched, 'display-name': 'Plivo 2' });
    // Toggling resends the fetched config, masked secrets included, as the UI does.
    await mock.updateProvider('PLIVO', { ...(await mock.getProvider('PLIVO')), enabled: false });
    const after = await mock.getProvider('plivo');
    expect(after['display-name']).toBe('Plivo 2');
    expect(after.enabled).toBe(false);
    // "****" only works for a secret the server already has.
    await expect(
      mock.updateProvider('PLIVO', { ...after, variables: { ...after.variables, 'new-secret': '****' } }),
    ).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
  });

  it('every provider can be edited and removed', async () => {
    const twilio = await mock.getProvider('TWILIO');
    await expect(mock.updateProvider('TWILIO', { ...twilio, 'display-name': 'Twilio 2' })).resolves.toMatchObject({
      'display-name': 'Twilio 2',
    });
    await expect(mock.deleteProvider('MSG91')).resolves.toBeNull();
    await expect(mock.getProvider('MSG91')).rejects.toMatchObject({ code: 'PROVIDER_NOT_FOUND' });
  });
});

describe('mock sends', () => {
  it('sends through the named provider', async () => {
    const res = await mock.sendSms({ type: 'SMS', provider: 'twilio', to: '+910000000001', body: 'Hello' });
    expect(res).toMatchObject({ status: 'ACCEPTED', provider: 'TWILIO', providerStatus: 'queued' });
    expect(res.providerMessageId).toMatch(/^SM/);
  });

  it('needs a registered provider, like the backend', async () => {
    await expect(mock.sendSms({ type: 'SMS', to: '+910000000001', body: 'Hello' })).rejects.toMatchObject({
      status: 400,
      code: 'VALIDATION_FAILED',
      problems: ['provider must not be blank'],
    });
    await expect(mock.sendSms({ type: 'SMS', provider: 'NOPE', to: '+910000000001', body: 'Hello' })).rejects.toMatchObject({
      status: 400,
      code: 'UNSUPPORTED_PROVIDER',
    });
  });

  it('rejects disabled providers with 503', async () => {
    await expect(
      mock.sendSms({ type: 'SMS', provider: 'textlocal', to: '+910000000001', body: 'Hello' }),
    ).rejects.toMatchObject({ status: 503, code: 'PROVIDER_UNAVAILABLE' });
  });

  it('attaches the problem body to failed sends', async () => {
    await expect(mock.sendSms({ type: 'SMS', provider: 'TWILIO', to: '+910000001000', body: 'Hello' })).rejects.toMatchObject({
      status: 502,
      body: { status: 502, code: 'PROVIDER_REJECTED', title: 'Provider rejected the message', providerErrorCode: '21211' },
    });
  });
});
