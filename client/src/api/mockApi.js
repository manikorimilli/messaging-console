// In-memory imitation of the backend for development and testing.
// State lives only in this module, so a page reload resets it. Nothing is
// written to browser storage.
//
// Simulated outcomes, by the last digits of the recipient number:
//   ...000  provider rejects the number (PROVIDER_REJECTED, code 21211)
//   ...999  provider times out (PROVIDER_TIMEOUT)
//   others  accepted
import { ApiError } from './ApiError.js';
import { MOCK_PROVIDERS } from './mockData.js';
import { MASKED_VALUE } from '../utils/providerConfig.js';
import { BODY_MAX_LENGTH, E164_PATTERN, validateProviderConfig } from '../utils/validation.js';

const SECRET_NAME = /secret|token|password|key/i;

let store = new Map();
let latencyMs = 450;

export function resetMockStore() {
  store = new Map(MOCK_PROVIDERS.map((p) => [p.id, structuredClone(p)]));
}
resetMockStore();

export function setMockLatency(ms) {
  latencyMs = ms;
}

const wait = () =>
  latencyMs > 0
    ? new Promise((resolve) => setTimeout(resolve, latencyMs * (0.6 + Math.random() * 0.8)))
    : Promise.resolve();

function randomHex(length) {
  let out = '';
  while (out.length < length) out += Math.floor(Math.random() * 16).toString(16);
  return out;
}

function toResponse(stored) {
  const copy = structuredClone(stored);
  if (copy.variables) {
    for (const key of Object.keys(copy.variables)) {
      if (SECRET_NAME.test(key)) copy.variables[key] = MASKED_VALUE;
    }
  }
  // Same key order as the backend example.
  const { id, 'display-name': displayName, channel, enabled, variables, request, response, ...rest } = copy;
  return { id, 'display-name': displayName, channel, enabled, variables, request, response, ...rest };
}

// Mirrors the backend's problem response, including the body it would send.
function problem(status, code, title, detail, extra = {}) {
  const body = { title, status, detail, code, ...extra };
  return new ApiError({ status, code, title, detail, ...extra, body });
}

function findStored(id) {
  const stored = store.get(String(id).toUpperCase());
  if (!stored) {
    throw problem(404, 'PROVIDER_NOT_FOUND', 'Provider not found', `No provider with id '${id}' exists.`);
  }
  return stored;
}

function validationFailed(detail, problems) {
  return problem(400, 'VALIDATION_FAILED', 'Validation failed', detail, { problems });
}

export async function listProviders() {
  await wait();
  return [...store.values()].sort((a, b) => a.id.localeCompare(b.id)).map(toResponse);
}

export async function getProvider(id) {
  await wait();
  return toResponse(findStored(id));
}

export async function registerProvider(payload) {
  await wait();
  const { problems } = validateProviderConfig(payload, { mode: 'create' });
  if (problems.length) throw validationFailed('The provider configuration is invalid.', problems);

  const id = payload.id.toUpperCase();
  if (store.has(id)) {
    throw problem(409, 'PROVIDER_ALREADY_EXISTS', 'Provider already exists', `A provider with id '${id}' already exists.`);
  }
  const stored = { ...structuredClone(payload), id, enabled: payload.enabled ?? true };
  store.set(id, stored);
  return toResponse(stored);
}

export async function updateProvider(id, payload) {
  await wait();
  const stored = findStored(id);

  const { problems } = validateProviderConfig(payload, { mode: 'update', pathId: stored.id });
  const variables = structuredClone(payload.variables ?? {});
  for (const [key, value] of Object.entries(variables)) {
    if (value !== MASKED_VALUE) continue;
    // "****" means "keep the stored secret".
    if (stored.variables && key in stored.variables) variables[key] = stored.variables[key];
    else problems.push(`variables.${key} is masked but no stored value exists`);
  }
  if (problems.length) throw validationFailed('The provider configuration is invalid.', problems);

  const updated = {
    ...structuredClone(payload),
    id: stored.id,
    enabled: payload.enabled ?? stored.enabled,
    variables,
  };
  store.set(stored.id, updated);
  return toResponse(updated);
}

export async function deleteProvider(id) {
  await wait();
  const stored = findStored(id);
  store.delete(stored.id);
  return null;
}

function checkMessage(payload) {
  if (payload.type !== 'SMS') {
    throw problem(400, 'UNSUPPORTED_MESSAGE_TYPE', 'Unsupported message type',
      `Message type '${payload.type}' is not supported. Only SMS is available.`);
  }
  const problems = [];
  if (typeof payload.body !== 'string' || payload.body.trim().length === 0) problems.push('body must not be blank');
  else if (payload.body.length > BODY_MAX_LENGTH) problems.push(`body must be at most ${BODY_MAX_LENGTH} characters`);
  return problems;
}

function resolveProvider(providerId) {
  const stored = providerId ? store.get(String(providerId).trim().toUpperCase()) : undefined;
  if (!stored) {
    const known = store.size ? `Registered providers: ${[...store.keys()].sort().join(', ')}.` : 'No providers are registered.';
    throw problem(400, 'UNSUPPORTED_PROVIDER', 'Unsupported provider', `Provider '${providerId}' is not registered. ${known}`);
  }
  if (stored.channel !== 'SMS') {
    throw problem(400, 'UNSUPPORTED_MESSAGE_TYPE', 'Unsupported message type', `Provider '${stored.id}' does not support SMS.`);
  }
  if (!stored.enabled) {
    throw problem(503, 'PROVIDER_UNAVAILABLE', 'Provider unavailable', `Provider '${stored.id}' is disabled.`);
  }
  return stored;
}

function simulateProvider(providerId, to) {
  if (to.endsWith('000')) {
    return { status: 'FAILED', code: 'PROVIDER_REJECTED', providerErrorCode: '21211', detail: 'Invalid number' };
  }
  if (to.endsWith('999')) {
    return { status: 'FAILED', code: 'PROVIDER_TIMEOUT', detail: 'Provider did not respond within 10 seconds' };
  }
  if (providerId === 'TWILIO') return { status: 'ACCEPTED', providerMessageId: `SM${randomHex(32)}`, providerStatus: 'queued' };
  if (providerId === 'VONAGE') return { status: 'ACCEPTED', providerMessageId: randomHex(16).toUpperCase(), providerStatus: '0' };
  return { status: 'ACCEPTED', providerMessageId: randomHex(24), providerStatus: 'accepted' };
}

export async function sendSms(payload) {
  await wait();
  const problems = checkMessage(payload);
  if (typeof payload.provider !== 'string' || !payload.provider.trim()) problems.push('provider must not be blank');
  if (typeof payload.to !== 'string' || !E164_PATTERN.test(payload.to)) problems.push('to must be a valid E.164 phone number');
  if (problems.length) throw validationFailed('The message request is invalid.', problems);

  const provider = resolveProvider(payload.provider);
  const result = simulateProvider(provider.id, payload.to);
  if (result.code === 'PROVIDER_REJECTED') {
    throw problem(502, result.code, 'Provider rejected the message', result.detail, { providerErrorCode: result.providerErrorCode });
  }
  if (result.code === 'PROVIDER_TIMEOUT') {
    throw problem(504, result.code, 'Provider timed out', result.detail);
  }
  return {
    status: 'ACCEPTED',
    provider: provider.id,
    providerMessageId: result.providerMessageId,
    providerStatus: result.providerStatus,
    acceptedAt: new Date().toISOString(),
  };
}
