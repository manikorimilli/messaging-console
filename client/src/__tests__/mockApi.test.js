import { beforeEach, describe, expect, it } from 'vitest';
import * as mock from '../api/mockApi.js';
import { PROVIDER_EXAMPLE } from '../utils/providerConfig.js';

// PROVIDER_EXAMPLE registers as PLIVO, an enabled SMS provider.
const DISABLED = { ...PROVIDER_EXAMPLE, id: 'quiet', 'display-name': 'Quiet', enabled: false };

beforeEach(() => {
  mock.setMockLatency(0);
  mock.resetMockStore();
});

describe('mock providers', () => {
  it('starts with no providers, like a fresh backend', async () => {
    await expect(mock.listProviders()).resolves.toEqual([]);
  });

  it('registers with uppercase id, masks secrets, rejects duplicates', async () => {
    const saved = await mock.registerProvider(PROVIDER_EXAMPLE);
    expect(saved).toMatchObject({ id: 'PLIVO', channel: 'SMS', enabled: true });
    expect(saved.variables['auth-token']).toBe('****');
    expect(saved.variables.from).toBe('+10000000001');
    await expect(mock.registerProvider(PROVIDER_EXAMPLE)).rejects.toMatchObject({ status: 409, code: 'PROVIDER_ALREADY_EXISTS' });
  });

  it('lists providers sorted by id and looks them up case-insensitively', async () => {
    await mock.registerProvider(PROVIDER_EXAMPLE);
    await mock.registerProvider(DISABLED);
    expect((await mock.listProviders()).map((p) => p.id)).toEqual(['PLIVO', 'QUIET']);
    await expect(mock.getProvider('plivo')).resolves.toMatchObject({ id: 'PLIVO' });
    await expect(mock.getProvider('nope')).rejects.toMatchObject({ status: 404, code: 'PROVIDER_NOT_FOUND' });
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

  it('removes a provider', async () => {
    await mock.registerProvider(PROVIDER_EXAMPLE);
    await expect(mock.deleteProvider('plivo')).resolves.toBeNull();
    await expect(mock.getProvider('PLIVO')).rejects.toMatchObject({ code: 'PROVIDER_NOT_FOUND' });
  });
});

describe('mock sends', () => {
  beforeEach(async () => {
    await mock.registerProvider(PROVIDER_EXAMPLE);
    await mock.registerProvider(DISABLED);
  });

  it('sends through the named provider', async () => {
    const res = await mock.sendSms({ type: 'SMS', provider: 'plivo', to: '+910000000001', body: 'Hello' });
    expect(res).toMatchObject({ status: 'ACCEPTED', provider: 'PLIVO', providerStatus: 'accepted' });
    expect(res.providerMessageId).toBeTruthy();
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
      detail: "Provider 'NOPE' is not registered. Registered providers: PLIVO, QUIET.",
    });
  });

  it('rejects disabled providers with 503', async () => {
    await expect(mock.sendSms({ type: 'SMS', provider: 'quiet', to: '+910000000001', body: 'Hello' })).rejects.toMatchObject({
      status: 503,
      code: 'PROVIDER_UNAVAILABLE',
    });
  });

  it('attaches the problem body to failed sends', async () => {
    await expect(mock.sendSms({ type: 'SMS', provider: 'PLIVO', to: '+910000001000', body: 'Hello' })).rejects.toMatchObject({
      status: 502,
      body: { status: 502, code: 'PROVIDER_REJECTED', title: 'Provider rejected the message', providerErrorCode: '21211' },
    });
  });
});
